import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

# Check startup logs
for cmd in [
    'docker logs soobshio_backend 2>&1 | grep -i "startup\|table\|gamif\|verified\|warning\|could not init" | head -20',
    # Manually create tables
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "CREATE TABLE IF NOT EXISTS user_gamification (id SERIAL PRIMARY KEY, telegram_id INTEGER UNIQUE NOT NULL, xp INTEGER DEFAULT 0, streak INTEGER DEFAULT 0, last_active TIMESTAMP, district TEXT, invite_code TEXT UNIQUE, invited_by INTEGER);" 2>&1',
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "CREATE TABLE IF NOT EXISTS user_achievements (id SERIAL PRIMARY KEY, telegram_id INTEGER NOT NULL, achievement_id TEXT NOT NULL, unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(telegram_id, achievement_id));" 2>&1',
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "CREATE TABLE IF NOT EXISTS user_quests (id SERIAL PRIMARY KEY, telegram_id INTEGER NOT NULL, quest_type TEXT NOT NULL, progress INTEGER DEFAULT 0, target INTEGER DEFAULT 0, reward_xp INTEGER DEFAULT 0, completed BOOLEAN DEFAULT FALSE, week_start TIMESTAMP, UNIQUE(telegram_id, quest_type));" 2>&1',
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "CREATE TABLE IF NOT EXISTS city_memes (id SERIAL PRIMARY KEY, image_url TEXT, caption TEXT, category TEXT, meme_type TEXT, likes INTEGER DEFAULT 0, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);" 2>&1',
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "CREATE TABLE IF NOT EXISTS user_reactions (id SERIAL PRIMARY KEY, telegram_id INTEGER NOT NULL, report_id INTEGER NOT NULL, reaction_type TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(telegram_id, report_id, reaction_type));" 2>&1',
    # Verify
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "\\dt" 2>&1 | grep -i "user_\|city_"',
]:
    print(f'$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=20)
    time.sleep(5)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out: print(f'OUT: {out[:400]}')
    if err: print(f'ERR: {err[:200]}')
    print('='*40)

# Restart backend
print('\nRestarting backend...')
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose restart backend 2>&1', timeout=60)
time.sleep(15)

# Test
for cmd in [
    'curl -s http://127.0.0.1/api/gamification/achievements 2>&1 | head -5',
    'curl -s -X POST "http://127.0.0.1/api/gamification/memes/generate?telegram_id=1&category=random" 2>&1 | head -5',
    'curl -s "http://127.0.0.1/api/gamification/leaderboard?limit=3" 2>&1 | head -3',
    'curl -s "http://127.0.0.1/api/gamification/profile/1" 2>&1 | head -3',
]:
    print(f'\n$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(4)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(f'  {out[:300]}')
    print('-'*40)

ssh.close()
print('\nDONE ✅')
