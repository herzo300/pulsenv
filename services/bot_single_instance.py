"""
Проверка единственного экземпляра бота (lock-файл).
Предотвращает TelegramConflictError при нескольких getUpdates.
"""
import os
import sys
import atexit

_lock_file = None


def _data_dir():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    d = os.path.join(base, "data")
    os.makedirs(d, exist_ok=True)
    return d


def _lock_path():
    return os.path.join(_data_dir(), "telegram_bot.lock")


def _pid_alive(pid: int) -> bool:
    """Проверяет, жив ли процесс с данным PID."""
    try:
        if sys.platform == "win32":
            import ctypes
            k32 = ctypes.windll.kernel32  # type: ignore
            handle = k32.OpenProcess(0x1000, False, pid)  # QUERY_INFORMATION
            if handle:
                k32.CloseHandle(handle)
                return True
            return False
        else:
            os.kill(pid, 0)
            return True
    except (OSError, AttributeError):
        return False


def acquire_lock() -> bool:
    """
    Захватывает lock. Возвращает True если успешно, False если другой экземпляр уже запущен.
    """
    global _lock_file
    path = _lock_path()
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                old_pid = int(f.read().strip())
            if _pid_alive(old_pid):
                return False
        except (ValueError, OSError):
            pass
        try:
            os.remove(path)
        except OSError:
            pass
    try:
        pid = os.getpid()
        with open(path, "w") as f:
            f.write(str(pid))
        _lock_file = path

        def _release():
            global _lock_file
            if _lock_file and os.path.exists(_lock_file):
                try:
                    os.remove(_lock_file)
                except OSError:
                    pass
                _lock_file = None

        atexit.register(_release)
        return True
    except OSError:
        return False


def release_lock():
    """Освобождает lock (вызывается при выходе)."""
    global _lock_file
    if _lock_file and os.path.exists(_lock_file):
        try:
            os.remove(_lock_file)
        except OSError:
            pass
        _lock_file = None
