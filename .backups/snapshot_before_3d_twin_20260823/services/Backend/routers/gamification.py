# services/Backend/routers/gamification.py
"""
Gamification system — XP, levels, achievements, streaks, quests, leaderboard.
"""

import logging
import random
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from services.data_layer.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/gamification", tags=["gamification"])

# ─── Constants ───
LEVELS = [
    (0, "Новичок", "🌱"),
    (100, "Наблюдатель", "👀"),
    (300, "Активист", "📢"),
    (700, "Страж города", "🛡️"),
    (1500, "Легенда Самотлора", "🏆"),
    (3000, "Хранитель Нижневартовска", "⭐"),
    (5000, "Городской Бог", "👑"),
]

ACHIEVEMENTS = [
    {
        "id": "first_complaint",
        "title": "Первый голос",
        "desc": "Подай первую жалобу",
        "icon": "🗣️",
        "xp": 50,
    },
    {
        "id": "five_complaints",
        "title": "Голос улиц",
        "desc": "Подай 5 жалоб",
        "icon": "📣",
        "xp": 100,
    },
    {
        "id": "ten_resolved",
        "title": "Решала",
        "desc": "10 жалоб решено",
        "icon": "✅",
        "xp": 200,
    },
    {
        "id": "streak_7",
        "title": "Неделя в теме",
        "desc": "7 дней подряд",
        "icon": "🔥",
        "xp": 150,
    },
    {
        "id": "streak_30",
        "title": "Месяц огня",
        "desc": "30 дней подряд",
        "icon": "💥",
        "xp": 500,
    },
    {
        "id": "meme_creator",
        "title": "Мемолог",
        "desc": "Создай первый мем",
        "icon": "😂",
        "xp": 75,
    },
    {
        "id": "inviter",
        "title": "Рекрутер",
        "desc": "Пригласи 3 друзей",
        "icon": "🤝",
        "xp": 200,
    },
    {
        "id": "road_warrior",
        "title": "Дорожный патруль",
        "desc": "5 жалоб про дороги",
        "icon": "🚗",
        "xp": 100,
    },
    {
        "id": "eco_warrior",
        "title": "Эко-воин",
        "desc": "5 жалоб про экологию",
        "icon": "🌿",
        "xp": 100,
    },
    {
        "id": "night_owl",
        "title": "Ночной дозор",
        "desc": "Жалоба после 23:00",
        "icon": "🦉",
        "xp": 50,
    },
    {
        "id": "early_bird",
        "title": "Ранняя пташка",
        "desc": "Жалоба до 7:00",
        "icon": "🐦",
        "xp": 50,
    },
    {
        "id": "hundred_club",
        "title": "Клуб 100",
        "desc": "100 XP за день",
        "icon": "💯",
        "xp": 150,
    },
]

QUEST_TEMPLATES = [
    {
        "type": "complaints_count",
        "title": "Активная неделя",
        "desc": "Подай 3 жалобы за неделю",
        "target": 3,
        "reward_xp": 200,
    },
    {
        "type": "different_categories",
        "title": "Разносторонний",
        "desc": "Подай жалобы из 3 разных категорий",
        "target": 3,
        "reward_xp": 250,
    },
    {
        "type": "check_cameras",
        "title": "Око города",
        "desc": "Проверь 10 камер",
        "target": 10,
        "reward_xp": 150,
    },
    {
        "type": "resolved_help",
        "title": "Помощник",
        "desc": "Помочь решить 2 проблемы (лайк/коммент)",
        "target": 2,
        "reward_xp": 180,
    },
    {
        "type": "streak_maintain",
        "title": "На связи",
        "desc": "Поддержи стрик 7 дней",
        "target": 7,
        "reward_xp": 300,
    },
]


def _get_level(xp: int) -> dict[str, Any]:
    """Get current level info for given XP."""
    current_level = LEVELS[0]
    for lvl_xp, name, icon in LEVELS:
        if xp >= lvl_xp:
            current_level = (lvl_xp, name, icon)
        else:
            break
    next_level = None
    for lvl_xp, name, icon in LEVELS:
        if lvl_xp > xp:
            next_level = (lvl_xp, name, icon)
            break
    progress = 0
    if next_level:
        progress = (xp - current_level[0]) / (next_level[0] - current_level[0])
    return {
        "xp": xp,
        "level": current_level[1],
        "level_icon": current_level[2],
        "level_xp": current_level[0],
        "next_level": next_level[1] if next_level else None,
        "next_level_icon": next_level[2] if next_level else None,
        "next_level_xp": next_level[0] if next_level else None,
        "progress": round(min(progress, 1.0), 2),
    }


def _calculate_streak(last_active: datetime | None) -> int:
    """Calculate consecutive day streak."""
    if not last_active:
        return 0
    now = datetime.now(UTC)
    last = (
        last_active.replace(tzinfo=UTC)
        if last_active.tzinfo is None
        else last_active
    )
    diff = (now - last).days
    if diff > 2:
        return 0
    if diff > 1:
        return 1
    return max(1, diff)  # Simplified; real impl would check daily activity log


@router.get("/profile/{telegram_id}")
def get_gamification_profile(telegram_id: int, db: Session = Depends(get_db)):
    """Get user gamification profile with XP, level, streaks, achievements."""
    if telegram_id == 0:
        return {
            "telegram_id": 0,
            "xp": 120,
            "level": "Наблюдатель",
            "level_icon": "👀",
            "level_xp": 100,
            "next_level": "Активист",
            "next_level_icon": "📢",
            "next_level_xp": 300,
            "progress": 0.1,
            "streak": 3,
            "last_active": datetime.now(UTC).isoformat(),
            "district": "Центральный",
            "invite_code": "GUEST86",
            "invited_by": None,
            "total_complaints": 2,
            "resolved_count": 1,
            "achievements_unlocked": 2,
            "achievements_total": len(ACHIEVEMENTS),
        }

    # Get or create user gamification record
    from services.data_layer.models import Report

    result = db.execute(
        text(
            "SELECT xp, streak, last_active, district, invite_code, invited_by FROM user_gamification WHERE telegram_id = :tid"
        ),
        {"tid": telegram_id},
    ).first()

    if not result:
        # Create initial record
        import secrets

        db.execute(
            text(
                "INSERT INTO user_gamification (telegram_id, xp, streak, last_active, invite_code) "
                "VALUES (:tid, 0, 0, :now, :code)"
            ),
            {
                "tid": telegram_id,
                "now": datetime.now(UTC),
                "code": secrets.token_urlsafe(8),
            },
        )
        db.commit()
        xp, streak, last_active, district, invite_code, invited_by = (
            0,
            0,
            None,
            None,
            "",
            None,
        )
    else:
        xp, streak, last_active, district, invite_code, invited_by = result

    # Count complaints
    total_complaints = (
        db.query(Report).filter(Report.source == f"user:{telegram_id}").count()
        if telegram_id
        else 0
    )
    resolved_count = (
        db.query(Report)
        .filter(Report.source == f"user:{telegram_id}", Report.status == "resolved")
        .count()
        if telegram_id
        else 0
    )

    # Check achievements
    unlocked_ids = []
    try:
        ach_result = db.execute(
            text(
                "SELECT achievement_id FROM user_achievements WHERE telegram_id = :tid"
            ),
            {"tid": telegram_id},
        ).fetchall()
        unlocked_ids = [r[0] for r in ach_result]
    except Exception as e:
        logger.warning("Failed to check achievements for %s: %s", telegram_id, e)

    level_info = _get_level(xp)

    return {
        "telegram_id": telegram_id,
        **level_info,
        "streak": streak,
        "last_active": last_active.isoformat() if last_active else None,
        "district": district,
        "invite_code": invite_code,
        "invited_by": invited_by,
        "total_complaints": total_complaints,
        "resolved_count": resolved_count,
        "achievements_unlocked": len(unlocked_ids),
        "achievements_total": len(ACHIEVEMENTS),
    }


@router.post("/award_xp")
def award_xp(
    telegram_id: int, amount: int, reason: str = "", db: Session = Depends(get_db)
):
    """Award XP to user and check for level-ups and achievements."""
    if telegram_id == 0:
        xp = 120 + amount
        new_level = _get_level(xp)
        return {
            "xp": xp,
            "xp_gained": amount,
            **new_level,
            "leveled_up": xp >= 300,
            "new_achievements": [],
        }

    result = db.execute(
        text(
            "SELECT xp, streak, last_active FROM user_gamification WHERE telegram_id = :tid"
        ),
        {"tid": telegram_id},
    ).first()

    if not result:
        import secrets

        db.execute(
            text(
                "INSERT INTO user_gamification (telegram_id, xp, streak, last_active, invite_code) VALUES (:tid, :xp, 0, :now, :code)"
            ),
            {
                "tid": telegram_id,
                "xp": amount,
                "now": datetime.now(UTC),
                "code": secrets.token_urlsafe(8),
            },
        )
        xp = amount
        old_level = _get_level(0)
    else:
        xp = result[0] + amount
        old_level = _get_level(result[0])
        db.execute(
            text(
                "UPDATE user_gamification SET xp = :xp, last_active = :now WHERE telegram_id = :tid"
            ),
            {"xp": xp, "now": datetime.now(UTC), "tid": telegram_id},
        )

    db.commit()

    new_level = _get_level(xp)
    leveled_up = old_level["level"] != new_level["level"]

    # Check achievements
    new_achievements = []
    try:
        _check_achievements(db, telegram_id, xp, reason)
        ach_result = db.execute(
            text(
                "SELECT achievement_id FROM user_achievements WHERE telegram_id = :tid ORDER BY unlocked_at DESC LIMIT 3"
            ),
            {"tid": telegram_id},
        ).fetchall()
        new_achievements = [r[0] for r in ach_result]
    except Exception as e:
        logger.warning("Failed to check achievements for %s: %s", telegram_id, e)

    return {
        "xp": xp,
        "xp_gained": amount,
        **new_level,
        "leveled_up": leveled_up,
        "new_achievements": new_achievements,
    }


def _check_achievements(db, telegram_id: int, xp: int, reason: str = ""):
    """Check and award achievements."""
    try:
        unlocked = db.execute(
            text(
                "SELECT achievement_id FROM user_achievements WHERE telegram_id = :tid"
            ),
            {"tid": telegram_id},
        ).fetchall()
        unlocked_ids = {r[0] for r in unlocked}
    except Exception as e:
        logger.warning("Failed to get unlocked achievements for %s: %s", telegram_id, e)
        unlocked_ids = set()

    # Count complaints for this user
    total_complaints = (
        db.execute(
            text("SELECT COUNT(*) FROM reports WHERE source = :src"),
            {"src": f"user:{telegram_id}"},
        ).scalar()
        or 0
    )

    resolved_count = (
        db.execute(
            text(
                "SELECT COUNT(*) FROM reports WHERE source = :src AND status = 'resolved'"
            ),
            {"src": f"user:{telegram_id}"},
        ).scalar()
        or 0
    )

    checks = {
        "first_complaint": total_complaints >= 1,
        "five_complaints": total_complaints >= 5,
        "ten_resolved": resolved_count >= 10,
    }

    for ach_id, condition in checks.items():
        if condition and ach_id not in unlocked_ids:
            ach = next((a for a in ACHIEVEMENTS if a["id"] == ach_id), None)
            if ach:
                db.execute(
                    text(
                        "INSERT OR IGNORE INTO user_achievements (telegram_id, achievement_id, unlocked_at) "
                        "VALUES (:tid, :aid, :now)"
                    ),
                    {"tid": telegram_id, "aid": ach_id, "now": datetime.now(UTC)},
                )
                db.execute(
                    text(
                        "UPDATE user_gamification SET xp = xp + :xp WHERE telegram_id = :tid"
                    ),
                    {"xp": ach["xp"], "tid": telegram_id},
                )
                db.commit()


@router.get("/achievements")
def get_achievements(telegram_id: int | None = None, db: Session = Depends(get_db)):
    """List all achievements with unlock status."""
    unlocked_times = {}
    unlocked_ids = set()
    if telegram_id == 0:
        unlocked_ids = {"first_complaint", "five_complaints"}
        unlocked_times = {
            "first_complaint": datetime.now(UTC).isoformat(),
            "five_complaints": datetime.now(UTC).isoformat()
        }
        return {
            "achievements": [
                {
                    **ach,
                    "unlocked": ach["id"] in unlocked_ids,
                    "unlocked_at": unlocked_times.get(ach["id"]),
                }
                for ach in ACHIEVEMENTS
            ]
        }

    if telegram_id:
        try:
            result = db.execute(
                text(
                    "SELECT achievement_id, unlocked_at FROM user_achievements WHERE telegram_id = :tid"
                ),
                {"tid": telegram_id},
            ).fetchall()
            unlocked_ids = {r[0] for r in result}
            unlocked_times = {r[0]: r[1].isoformat() for r in result}
        except Exception as e:
            logger.warning("Failed to get user achievements for %s: %s", telegram_id, e)
            unlocked_times = {}

    return {
        "achievements": [
            {
                **ach,
                "unlocked": ach["id"] in unlocked_ids,
                "unlocked_at": unlocked_times.get(ach["id"]),
            }
            for ach in ACHIEVEMENTS
        ]
    }


@router.get("/leaderboard")
def get_leaderboard(
    district: str | None = None, limit: int = 50, db: Session = Depends(get_db)
):
    """Get XP leaderboard, optionally filtered by district."""
    query = """
        SELECT telegram_id, xp, district, invite_code
        FROM user_gamification
        WHERE xp > 0
    """
    params: dict = {"limit": limit}

    if district:
        query += " AND district = :district"
        params["district"] = district

    query += " ORDER BY xp DESC LIMIT :limit"

    rows = db.execute(text(query), params).fetchall()

    leaderboard = []
    for i, (tid, xp, dist, code) in enumerate(rows):
        lvl = _get_level(xp)
        leaderboard.append(
            {
                "rank": i + 1,
                "telegram_id": tid,
                "xp": xp,
                **lvl,
                "district": dist,
            }
        )

    return {"leaderboard": leaderboard, "district": district or "all"}


@router.get("/quests")
def get_quests(telegram_id: int, db: Session = Depends(get_db)):
    """Get weekly quests for user."""
    if telegram_id == 0:
        return {
            "quests": [
                {
                    "type": "complaints_count",
                    "title": "Активная неделя",
                    "desc": "Подай 3 жалобы за неделю",
                    "target": 3,
                    "progress": 1,
                    "reward_xp": 200,
                    "completed": False,
                },
                {
                    "type": "check_cameras",
                    "title": "Око города",
                    "desc": "Проверь 10 камер",
                    "target": 10,
                    "progress": 5,
                    "reward_xp": 150,
                    "completed": False,
                },
                {
                    "type": "resolved_help",
                    "title": "Помощник",
                    "desc": "Помочь решить 2 проблемы (лайк/коммент)",
                    "target": 2,
                    "progress": 2,
                    "reward_xp": 180,
                    "completed": True,
                }
            ],
            "week_start": (datetime.now(UTC) - timedelta(days=datetime.now(UTC).weekday())).isoformat()
        }

    # Check if quests need refresh (weekly)
    now = datetime.now(UTC)
    week_start = now - timedelta(days=now.weekday())

    result = db.execute(
        text(
            "SELECT quest_type, progress, target, completed, reward_xp, week_start FROM user_quests WHERE telegram_id = :tid"
        ),
        {"tid": telegram_id},
    ).fetchall()

    quests = []
    for row in result:
        qtype, progress, target, completed, reward, ws = row
        template = next((q for q in QUEST_TEMPLATES if q["type"] == qtype), None)
        if template:
            needs_reset = ws and ws < week_start
            quests.append(
                {
                    **template,
                    "progress": progress if not needs_reset else 0,
                    "completed": completed if not needs_reset else False,
                    "needs_reset": needs_reset,
                }
            )

    # Assign quests if none exist
    if len(quests) < 3:
        assigned_types = {q["type"] for q in quests if not q.get("needs_reset", False)}
        available = [q for q in QUEST_TEMPLATES if q["type"] not in assigned_types]
        random.shuffle(available)
        for q in available[: 3 - len(quests)]:
            quests.append(
                {
                    **q,
                    "progress": 0,
                    "completed": False,
                    "needs_reset": False,
                }
            )
            # Save to DB
            try:
                db.execute(
                    text(
                        "INSERT INTO user_quests (telegram_id, quest_type, progress, target, reward_xp, week_start) "
                        "VALUES (:tid, :qt, 0, :tgt, :rxp, :ws)"
                    ),
                    {
                        "tid": telegram_id,
                        "qt": q["type"],
                        "tgt": q["target"],
                        "rxp": q["reward_xp"],
                        "ws": week_start,
                    },
                )
                db.commit()
            except Exception as e:
                logger.warning("Failed to save quest for %s: %s", telegram_id, e)
                db.rollback()

    return {"quests": quests, "week_start": week_start.isoformat()}


@router.post("/quest/progress")
def update_quest_progress(
    telegram_id: int, quest_type: str, amount: int = 1, db: Session = Depends(get_db)
):
    """Update quest progress."""
    if telegram_id == 0:
        return {
            "quest_type": quest_type,
            "progress": amount,
            "target": 5,
            "completed": False,
            "reward_xp": 0,
        }

    result = db.execute(
        text(
            "SELECT progress, target, reward_xp, completed FROM user_quests "
            "WHERE telegram_id = :tid AND quest_type = :qt"
        ),
        {"tid": telegram_id, "qt": quest_type},
    ).first()

    if not result:
        return {"error": "quest_not_found"}

    progress, target, reward, completed = result
    if completed:
        return {"completed": True, "progress": progress}

    new_progress = progress + amount
    completed_flag = new_progress >= target

    db.execute(
        text(
            "UPDATE user_quests SET progress = :prog, completed = :comp "
            "WHERE telegram_id = :tid AND quest_type = :qt"
        ),
        {
            "prog": new_progress,
            "comp": completed_flag,
            "tid": telegram_id,
            "qt": quest_type,
        },
    )
    db.commit()

    if completed_flag:
        # Award XP
        db.execute(
            text(
                "UPDATE user_gamification SET xp = xp + :rxp WHERE telegram_id = :tid"
            ),
            {"rxp": reward, "tid": telegram_id},
        )
        db.commit()

    return {
        "quest_type": quest_type,
        "progress": new_progress,
        "target": target,
        "completed": completed_flag,
        "reward_xp": reward if completed_flag else 0,
    }


@router.get("/memes")
def get_memes(limit: int = 20, db: Session = Depends(get_db)):
    """Get AI-generated city memes."""
    rows = db.execute(
        text(
            "SELECT id, image_url, caption, category, likes, created_at FROM city_memes ORDER BY created_at DESC LIMIT :limit"
        ),
        {"limit": limit},
    ).fetchall()

    return {
        "memes": [
            {
                "id": r[0],
                "image_url": r[1],
                "caption": r[2],
                "category": r[3],
                "likes": r[4],
                "created_at": r[5].isoformat() if r[5] else None,
            }
            for r in rows
        ]
    }


@router.post("/memes/generate")
async def generate_meme(
    telegram_id: int,
    report_id: int | None = None,
    category: str = "random",
    db: Session = Depends(get_db)
):
    """Generate a city meme using AI."""
    from services.ai.meme_service import generate_meme_for_report

    # If no report_id is provided, try to find a random recent report
    if not report_id:
        try:
            # PostgreSQL/SQLite compatible random row
            row = db.execute(text("SELECT id FROM reports ORDER BY RANDOM() LIMIT 1")).first()
            if row:
                report_id = row[0]
        except Exception as e:
            logger.warning("Failed to fetch random report for meme: %s", e)

    meme_result = None
    if report_id:
        try:
            meme_result = await generate_meme_for_report(report_id, db)
        except Exception as exc:
            logger.warning("Dynamic meme generation failed for report #%s: %s", report_id, exc)

    # Fallback to local hardcoded templates if dynamic generation failed or no report was found
    if not meme_result or "error" in meme_result:
        meme_templates = {
            "Дороги": [
                {
                    "caption": "Когда сказал что дорога хорошая 😂\n📸 *ожидание vs реальность*",
                    "meme_type": "expectation_vs_reality",
                },
                {
                    "caption": "Понедельник на дороге Нижневартовска:\n🚗🚗💥🚗",
                    "meme_type": "chaos",
                },
                {
                    "caption": "Яма на дороге: 'ты кто такой?'\nАвто: 'я твоё подвеска'\n💀",
                    "meme_type": "dialogue",
                },
            ],
            "ЖКХ": [
                {
                    "caption": "Когда отопление включили в апреле\n🥵 'Ну наконец-то!'",
                    "meme_type": "seasonal",
                },
                {
                    "caption": "Лифт в Нижневартовске:\nЗастрял? Это не баг, это фича 🛗",
                    "meme_type": "humor",
                },
            ],
            "Экология": [
                {
                    "caption": "Свалка в парке: 'я тут главная'\nПрирода: 'нет' 🌿😤",
                    "meme_type": "fight",
                },
            ],
            "random": [
                {
                    "caption": "Нижневартовск в -40°C:\n'Нормально, тепло!' 🥶🔥",
                    "meme_type": "weather",
                },
                {
                    "caption": "Когда друг говорит 'тут близко'\n*50 минут на маршрутке* 🚌💨",
                    "meme_type": "transport",
                },
            ],
        }

        templates = meme_templates.get(category, meme_templates["random"])
        chosen = random.choice(templates)
        caption = chosen["caption"]
        meme_type = chosen["meme_type"]
        # Use a placeholder standard image URL or a fallback local gradient
        image_url = "https://api.memegen.link/images/sad-keanu/City_Pulse/Meme_Fallback.png"
        
        # Save to DB
        try:
            db.execute(
                text(
                    "INSERT INTO city_memes (caption, image_url, category, meme_type, created_at) "
                    "VALUES (:cap, :url, :cat, :type, :now)"
                ),
                {"cap": caption, "url": image_url, "cat": category, "type": meme_type, "now": datetime.now(UTC).replace(tzinfo=None)},
            )
            db.commit()
        except Exception as dberr:
            logger.warning("Failed to save fallback meme: %s", dberr)
            db.rollback()

        meme_result = {
            "caption": caption,
            "image_url": image_url,
            "meme_type": meme_type,
            "category": category,
            "share_text": f"🏙️ Мем от Нижневартовского City Pulse\n\n{caption}"
        }

    # Award XP for meme creation
    try:
        award_xp(
            telegram_id=telegram_id,
            amount=25,
            reason="meme_created",
            db=db
        )
    except Exception as e:
        logger.warning(
            "Failed to award XP for meme creation for %s: %s", telegram_id, e
        )

    return {
        "meme": meme_result,
        "meme_type": meme_result.get("meme_type"),
        "category": meme_result.get("category"),
        "xp_earned": 25,
        "share_text": meme_result.get("share_text"),
        "image_url": meme_result.get("image_url")
    }



@router.post("/share")
def share_to_telegram(meme_id: int, channel: str, db: Session = Depends(get_db)):
    """Generate shareable link/text for Telegram or VK."""
    row = db.execute(
        text("SELECT caption, category FROM city_memes WHERE id = :mid"),
        {"mid": meme_id},
    ).first()

    if not row:
        return {"error": "meme_not_found"}

    caption, category = row

    if channel == "telegram":
        share_text = f"🏙️ *Городской мем*\n\n{caption}\n\n— @monitornv | Пульс города Нижневартовск"
        share_url = f"https://t.me/share/url?url=https://soobshio.app&text={caption}"
    elif channel == "vk":
        share_text = f"🏙️ Городской мем\n\n{caption}\n\n— Пульс города Нижневартовск"
        share_url = "https://vk.com/share.php?url=https://soobshio.app"
    else:
        share_text = caption
        share_url = "https://soobshio.app"

    return {
        "share_text": share_text,
        "share_url": share_url,
        "channel": channel,
    }


@router.post("/invite")
def register_invite(invite_code: str, telegram_id: int, db: Session = Depends(get_db)):
    """Register invite and award XP to both parties."""
    if telegram_id == 0:
        return {
            "success": True,
            "inviter_id": 9999,
            "xp_earned": 50,
            "message": "🎉 Добро пожаловать! +50 XP тебе и другу!",
        }

    # Find inviter
    inviter = db.execute(
        text("SELECT telegram_id FROM user_gamification WHERE invite_code = :code"),
        {"code": invite_code},
    ).first()

    if not inviter:
        return {"error": "invalid_code"}

    inviter_id = inviter[0]

    # Award XP
    db.execute(
        text("UPDATE user_gamification SET xp = xp + 50 WHERE telegram_id = :tid"),
        {"tid": telegram_id},
    )
    db.execute(
        text("UPDATE user_gamification SET xp = xp + 50 WHERE telegram_id = :tid"),
        {"tid": inviter_id},
    )
    db.execute(
        text("UPDATE user_gamification SET invited_by = :inv WHERE telegram_id = :tid"),
        {"inv": inviter_id, "tid": telegram_id},
    )
    db.commit()

    return {
        "success": True,
        "inviter_id": inviter_id,
        "xp_earned": 50,
        "message": "🎉 Добро пожаловать! +50 XP тебе и другу!",
    }


@router.get("/invites/{telegram_id}")
def get_invite_stats(telegram_id: int, db: Session = Depends(get_db)):
    """Get invite statistics for user."""
    if telegram_id == 0:
        return {
            "telegram_id": 0,
            "invite_code": "GUEST86",
            "invites_count": 0,
            "total_xp": 120,
            "invite_url": "https://t.me/SoobshioBot?start=invite_GUEST86",
        }

    invites = db.execute(
        text("SELECT COUNT(*) FROM user_gamification WHERE invited_by = :tid"),
        {"tid": telegram_id},
    ).scalar()

    user = db.execute(
        text("SELECT invite_code, xp FROM user_gamification WHERE telegram_id = :tid"),
        {"tid": telegram_id},
    ).first()

    if not user:
        return {"error": "user_not_found"}

    code, xp = user

    return {
        "telegram_id": telegram_id,
        "invite_code": code or "",
        "invites_count": invites,
        "total_xp": xp,
        "invite_url": f"https://t.me/SoobshioBot?start=invite_{code}",
    }


@router.get("/streak/{telegram_id}")
def get_streak(telegram_id: int, db: Session = Depends(get_db)):
    """Get user streak info."""
    if telegram_id == 0:
        return {
            "streak": 3,
            "last_active": datetime.now(UTC).isoformat(),
            "streak_active": True,
            "streak_milestone": False,
        }

    result = db.execute(
        text(
            "SELECT streak, last_active FROM user_gamification WHERE telegram_id = :tid"
        ),
        {"tid": telegram_id},
    ).first()

    if not result:
        return {"streak": 0, "last_active": None}

    streak, last_active = result

    # Calculate if streak is still active
    streak_active = True
    if last_active:
        diff = (datetime.now(UTC) - last_active).days
        streak_active = diff <= 2

    return {
        "streak": streak if streak_active else 0,
        "last_active": last_active.isoformat() if last_active else None,
        "streak_active": streak_active,
        "streak_milestone": streak >= 7 if streak_active else False,
    }
