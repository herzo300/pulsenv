#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Деплой на GitHub. Токен и репозиторий берутся из .env:
  GITHUB=ghp_xxx...
  GITHUB_REPO=owner/repo   (по умолчанию herzo300/pulsenv)
Если репозитория нет — создаётся через GitHub API (токен с правом repo).
Запуск из корня: py scripts/deployment/deploy_github.py
"""
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
os.chdir(ROOT)

# Загрузка .env
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except Exception:
    pass


def create_repo_if_missing(token: str, repo: str) -> bool:
    """Создаёт репозиторий на GitHub, если его нет. owner/repo."""
    parts = repo.split("/", 1)
    if len(parts) != 2:
        return False
    owner, name = parts
    req = urllib.request.Request(
        "https://api.github.com/user/repos",
        data=json.dumps({"name": name, "private": False}).encode(),
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status in (200, 201)
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        if e.code == 422:
            return True  # уже существует
        print(f"GitHub API {e.code}: {body[:200]}")
        return False
    except Exception as err:
        try:
            print("GitHub API error:", str(err)[:100])
        except Exception:
            print("GitHub API error (see traceback)")
        return False


def main():
    token = os.getenv("GITHUB", "").strip()
    repo = os.getenv("GITHUB_REPO", "herzo300/pulsenv").strip()
    if not token:
        print("GITHUB token not set in .env")
        return 1
    url = f"https://{token}@github.com/{repo}.git"

    br = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    branch = (br.stdout or "master").strip() or "master"

    # Попытка создать репозиторий, если пуш вернёт "not found"
    print(f"Push to https://github.com/{repo} branch {branch} ...")
    r = subprocess.run(
        ["git", "push", "-u", url, branch],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        out = (r.stderr or "") + (r.stdout or "")
        print(out.strip())
        if "not found" in out or "404" in out or "Repository not found" in out:
            print("Repo not found. Creating via GitHub API ...")
            if create_repo_if_missing(token, repo):
                r = subprocess.run(["git", "push", "-u", url, branch], cwd=ROOT)
        if r.returncode != 0:
            print("Push failed.")
            print("1) Create repo: https://github.com/new  name: pulsenv")
            print("2) In .env set GITHUB_REPO=Rosomaxa3/pulsenv (or your username)")
            print("3) Run this script again.")
            return 1
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
