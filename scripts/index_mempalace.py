"""
Индексация проекта в MemPalace — собираем только исходные файлы.
Создаёт временную директорию с копиями/хардлинками ключевых файлов,
затем запускает `mempalace mine` на ней.
"""

import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(r"c:\Soobshio_project")
STAGE_DIR = Path(r"c:\Soobshio_project\.mempalace_stage")

# Папки с исходным кодом (относительно PROJECT_ROOT)
SOURCE_DIRS = [
    "services/Backend",
    "services/Frontend/lib",
    "backend",
    "core",
    "api",
    "scripts",
    "docs",
    "ops",
    "tests",
    "tools",
]

# Отдельные файлы из корня
ROOT_FILES = [
    "main.py",
    "start_all_monitoring.py",
    "start_backend.py",
    "start_camera_probe.py",
    "docker-compose.yml",
    "Dockerfile",
    "requirements.txt",
    "README.md",
    "TECHNICAL_DOCUMENTATION.md",
    "BUSINESS_MODEL.md",
    "CLAUDE.md",
    ".env.example",
    "mempalace.yaml",
]

SKIP_EXTENSIONS = {
    ".pyc",
    ".pyo",
    ".pt",
    ".db",
    ".session",
    ".lock",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".webp",
    ".woff",
    ".woff2",
    ".ttf",
    ".eot",
    ".zip",
    ".tar",
    ".gz",
    ".7z",
}

SKIP_DIRS = {
    "__pycache__",
    ".git",
    ".venv",
    "node_modules",
    ".dart_tool",
    ".idea",
    "build",
    ".omc",
    ".agents",
    ".cursor",
    ".qwen",
    "~",
}


def should_skip(path: Path) -> bool:
    if path.suffix.lower() in SKIP_EXTENSIONS:
        return True
    for part in path.parts:
        if part in SKIP_DIRS:
            return True
    return False


def copy_tree(src: Path, dst: Path):
    """Copy source tree, skipping unwanted files."""
    count = 0
    for item in src.rglob("*"):
        if item.is_dir():
            continue
        if should_skip(item):
            continue
        rel = item.relative_to(src)
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(item, target)
            count += 1
        except (PermissionError, OSError):
            pass
    return count


def main():
    # Clean stage
    if STAGE_DIR.exists():
        shutil.rmtree(STAGE_DIR)
    STAGE_DIR.mkdir(parents=True)

    total = 0

    # Copy source directories
    for rel_dir in SOURCE_DIRS:
        src = PROJECT_ROOT / rel_dir
        if not src.exists():
            print(f"  [skip] {rel_dir} — not found")
            continue
        dst = STAGE_DIR / rel_dir
        n = copy_tree(src, dst)
        print(f"  [ok]   {rel_dir} — {n} files")
        total += n

    # Copy root files
    root_dst = STAGE_DIR
    for fname in ROOT_FILES:
        src = PROJECT_ROOT / fname
        if src.exists():
            shutil.copy2(src, root_dst / fname)
            total += 1

    print(f"\n  Total staged: {total} files")
    print(f"  Stage dir: {STAGE_DIR}\n")

    # Copy mempalace.yaml into stage
    yaml_src = PROJECT_ROOT / "mempalace.yaml"
    if yaml_src.exists():
        shutil.copy2(yaml_src, STAGE_DIR / "mempalace.yaml")

    # Run mempalace mine
    print("  Starting MemPalace mine...\n")
    env = {
        **dict(__import__("os").environ),
        "PYTHONIOENCODING": "utf-8",
        "PYTHONUTF8": "1",
    }
    result = subprocess.run(
        [
            str(PROJECT_ROOT / ".venv" / "Scripts" / "python.exe"),
            "-m",
            "mempalace",
            "mine",
            str(STAGE_DIR),
        ],
        env=env,
        cwd=str(STAGE_DIR),
    )

    if result.returncode == 0:
        print("\n  ✓ MemPalace mining complete!")
    else:
        print(f"\n  ✗ Mining failed with code {result.returncode}")

    # Cleanup stage
    # shutil.rmtree(STAGE_DIR, ignore_errors=True)

    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
