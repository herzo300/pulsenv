# tests/test_realtime_guard.py
"""
Тесты для RealtimeGuard: property-based (Hypothesis) + unit-тесты.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime, timezone, timedelta
from hypothesis import given, settings, strategies as st
from services.realtime_guard import RealtimeGuard, GuardStats


# ============================================================
# Property-based тесты (Hypothesis)
# ============================================================

@settings(max_examples=200)
@given(
    startup_offset=st.integers(min_value=-1000000, max_value=1000000),
    msg_offset=st.integers(min_value=-1000000, max_value=1000000),
)
def test_property1_timestamp_filtering(startup_offset, msg_offset):
    """Property 1: is_new_message возвращает True iff msg_time >= startup_time"""
    base = datetime(2025, 1, 1, tzinfo=timezone.utc)
    startup_time = base + timedelta(seconds=startup_offset)
    msg_time = base + timedelta(seconds=msg_offset)

    guard = RealtimeGuard()
    guard._startup_time = startup_time

    result = guard.is_new_message(msg_time)
    expected = msg_time >= startup_time
    assert result == expected, f"msg={msg_time}, startup={startup_time}, got={result}, expected={expected}"


@settings(max_examples=200)
@given(
    source=st.text(min_size=1, max_size=50),
    message_id=st.integers(min_value=0, max_value=10**9),
)
def test_property2_dedup_roundtrip(source, message_id):
    """Property 2: mark_processed → is_duplicate возвращает True"""
    guard = RealtimeGuard()
    guard.mark_processed(source, message_id)
    assert guard.is_duplicate(source, message_id), f"Дубликат не обнаружен: ({source}, {message_id})"


@settings(max_examples=50, deadline=None)
@given(
    pairs=st.lists(
        st.tuples(
            st.text(min_size=1, max_size=10, alphabet=st.characters(whitelist_categories=("L",))),
            st.integers(min_value=0, max_value=100000),
        ),
        min_size=0,
        max_size=15000,
    )
)
def test_property3_size_invariant(pairs):
    """Property 3: размер _processed_ids никогда не превышает max_size"""
    guard = RealtimeGuard(max_size=1000, trim_size=500)
    for source, msg_id in pairs:
        guard.mark_processed(source, msg_id)
        assert len(guard._processed_ids) <= guard._max_size, \
            f"Размер {len(guard._processed_ids)} > max {guard._max_size}"


# ============================================================
# Unit-тесты
# ============================================================

def test_message_at_startup_time_accepted():
    """Сообщение ровно в момент запуска — принято"""
    guard = RealtimeGuard()
    assert guard.is_new_message(guard.startup_time) is True


def test_message_before_startup_rejected():
    """Сообщение на 1 секунду раньше запуска — отклонено"""
    guard = RealtimeGuard()
    old_time = guard.startup_time - timedelta(seconds=1)
    assert guard.is_new_message(old_time) is False


def test_message_after_startup_accepted():
    """Сообщение после запуска — принято"""
    guard = RealtimeGuard()
    new_time = guard.startup_time + timedelta(seconds=10)
    assert guard.is_new_message(new_time) is True


def test_duplicate_detected():
    """Дубликат с тем же (source, id) — обнаружен"""
    guard = RealtimeGuard()
    guard.mark_processed("tg:test", 123)
    assert guard.is_duplicate("tg:test", 123) is True


def test_different_source_same_id_not_duplicate():
    """Разные source с одинаковым id — не дубликат"""
    guard = RealtimeGuard()
    guard.mark_processed("tg:channel1", 123)
    assert guard.is_duplicate("tg:channel2", 123) is False


def test_none_timestamp_accepted():
    """timestamp=None — сообщение считается новым"""
    guard = RealtimeGuard()
    assert guard.is_new_message(None) is True


def test_naive_datetime_handled():
    """naive datetime (без tzinfo) корректно обрабатывается"""
    guard = RealtimeGuard()
    # naive datetime в будущем — должно быть принято
    future = datetime.now(timezone.utc) + timedelta(hours=1)
    assert guard.is_new_message(future) is True


def test_stats_increment():
    """Статистика корректно инкрементируется"""
    guard = RealtimeGuard()

    # skipped_old
    old_time = guard.startup_time - timedelta(hours=1)
    guard.is_new_message(old_time)
    assert guard.stats.skipped_old == 1

    # processed_count
    guard.mark_processed("tg:test", 1)
    assert guard.stats.processed_count == 1

    # skipped_duplicate
    guard.is_duplicate("tg:test", 1)
    assert guard.stats.skipped_duplicate == 1


def test_trim_preserves_recent():
    """После очистки сохраняются последние записи"""
    guard = RealtimeGuard(max_size=100, trim_size=50)
    for i in range(110):
        guard.mark_processed("src", i)
    # После 101 вставки: trim до 50, потом ещё 9 = 59
    assert len(guard._processed_ids) <= guard._max_size
    # Последние должны быть сохранены
    assert guard.is_duplicate("src", 109) is True
    # Первые должны быть удалены (0..50 удалены при trim)
    assert guard.is_duplicate("src", 0) is False


def test_startup_time_is_utc():
    """startup_time имеет UTC timezone"""
    guard = RealtimeGuard()
    assert guard.startup_time.tzinfo is not None
    assert guard.startup_time.tzinfo == timezone.utc
