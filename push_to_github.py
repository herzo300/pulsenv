"""Push to GitHub using token from credential manager."""
import subprocess
import sys

def get_github_token():
    proc = subprocess.Popen(
        ['git', 'credential', 'fill'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = proc.communicate(input="protocol=https\nhost=github.com\n\n", timeout=10)
    for line in stdout.strip().split('\n'):
        if line.startswith('password='):
            return line.split('=', 1)[1]
    return None

token = get_github_token()
if not token:
    print("❌ Не удалось получить токен")
    sys.exit(1)

print(f"✅ Токен: {token[:8]}...")

# Set remote with token embedded
url = f"https://herzo300:{token}@github.com/herzo300/pulsenv.git"
subprocess.run(['git', 'remote', 'set-url', 'origin', url], check=True)

# Push
print("Pushing...")
result = subprocess.run(
    ['git', 'push', '--set-upstream', 'origin', 'main'],
    capture_output=True, text=True, timeout=120
)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("Return code:", result.returncode)

# Reset remote to clean URL (without token)
subprocess.run(['git', 'remote', 'set-url', 'origin', 'https://github.com/herzo300/pulsenv.git'])
