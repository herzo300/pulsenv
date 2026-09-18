# City Pulse Backup — Restore Instructions

**Created:** 2026-07-12
**Head commit at backup:** 8dbd2d2
**Backup of:** services/Frontend (Flutter app "Пульс Города")
**Reason:** Before implementing CityPulse_Improvements.md items 1,2,3,4,6,7

## Contents
- `working_tree/lib/`        — full copy of lib/ at backup time (incl. uncommitted changes)
- `working_tree/pubspec.yaml` — pubspec at backup time
- `working_tree/pubspec.lock` — pubspec.lock at backup time
- `uncommitted_changes.patch` — git diff HEAD for services/Frontend
- `head_commit.txt`           — commit SHA at backup

## How to restore

### Option A — full restore to backup state (working tree):
```bash
cd C:/Soobshio_project
rm -rf services/Frontend/lib
cp -r .backups/city_pulse_20260712_161550/working_tree/lib services/Frontend/lib
cp .backups/city_pulse_20260712_161550/working_tree/pubspec.yaml services/Frontend/pubspec.yaml
cp .backups/city_pulse_20260712_161550/working_tree/pubspec.lock services/Frontend/pubspec.lock
cd services/Frontend && flutter pub get
```

### Option B — restore only lib/ (keep new pubspec):
```bash
cd C:/Soobshio_project
rm -rf services/Frontend/lib
cp -r .backups/city_pulse_20260712_161550/working_tree/lib services/Frontend/lib
```

### Option C — git rollback to committed HEAD:
```bash
cd C:/Soobshio_project
git checkout 8dbd2d2 -- services/Frontend
```
