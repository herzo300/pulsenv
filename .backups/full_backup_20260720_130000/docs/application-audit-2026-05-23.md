# Application Audit - 2026-05-23

## Scope

- Backend: FastAPI entry point, routers, runtime metrics, VLM camera analysis.
- Frontend: Flutter design-token TODOs listed in `design-tokens/README.md`.
- Public web: static HTML pages listed in `design-tokens/README.md`.
- Verification: Python compile, targeted Ruff checks, Flutter analyze/tests.

## Completed Cleanup

- Migrated public HTML pages from local System B/C aliases to shared `design-tokens.css` variables:
  `app.html`, `info.html`, `cameras.html`, `city_dashboard.html`, `daily_report.html`,
  `privacy_policy.html`, `user_agreement.html`.
- Fixed invalid page-level CSS variable blocks in `cameras.html`, `city_dashboard.html`, and
  `daily_report.html` by wrapping token aliases in `:root`.
- Replaced targeted Flutter inline typography in `wow_effects.dart` with `AppTextStyles`.
- Replaced targeted `GoogleFonts.inter` / `GoogleFonts.orbitron` usage in infographic hero widgets
  with `AppTextStyles`.
- Rebuilt the active Flutter splash screen as a token-based city-pulse animation and removed the old
  splash visual direction from the launch flow.
- Finished the remaining design-token TODO paths in the Flutter map, complaint form, splash themes, and
  AI scan preview widgets.
- Removed the obsolete `shake` dependency path and kept shake-to-report behavior on `sensors_plus`, which
  avoids pulling the incompatible legacy `sensors` Android plugin into release builds.
- Fixed Flutter compile blockers in infographic loading UI, camera video dialog, and MCP WebSocket
  disconnect handling.
- Made `/vlm/describe` run blocking `ffmpeg` frame capture in a worker thread so the async event loop
  remains responsive.
- Removed redundant initial ordering from `/api/reports`; the endpoint now applies only the requested
  sort order.

## Performance Findings

- P0/P1: `services/Backend/routers/vlm.py` previously ran `subprocess.run(ffmpeg...)` directly inside
  an async route. This could block unrelated requests for the duration of camera frame capture. Fixed.
- P1: runtime request metrics are written through a fire-and-forget background task per request. This
  avoids request latency but can grow unbounded under high traffic. Next step: queue-backed single writer
  or sampling.
- P1: `services/Backend/routers/map_data.py` has caching and per-report timeouts, which is good, but it
  still performs geocoding enrichment in request flow when cache misses. Next step: move enrichment to a
  maintenance/backfill job and keep map feed reads hot.
- P2: public HTML still contains many page-local decorative colors after alias migration. The main token
  bridge is complete, but a stricter visual cleanup pass should replace remaining inline chart/accent
  literals only after screenshot comparison.
- P2: Flutter still has legacy localized text encoding in older files. It does not block compilation, but
  a separate UTF-8/content cleanup would improve maintainability.

## Verification

- `python -m compileall -q main.py core services\Backend services\business services\data_layer services\monitoring services\ai` passed.
- `python -m compileall -q services\Backend\routers\reports.py services\Backend\routers\vlm.py` passed.
- `python -m ruff check services\Backend\routers\vlm.py --select I,SIM115` passed.
- `flutter analyze lib/widgets/wow_effects.dart lib/screens/infographic/widgets/executive_summary_card.dart` passed.
- `flutter test test/city_stats_ticker_test.dart test/map_glass_panel_test.dart` passed.
- `python -m pytest -q` passed: 30 tests.
- `flutter analyze lib/screens/infographic_screen.dart lib/screens/map/widgets/video_dialog.dart lib/services/mcp_service.dart lib/screens/splash_screen.dart lib/screens/splash_theme.dart lib/screens/map_screen.dart lib/screens/complaint_form_screen.dart lib/widgets/ai_scan_preview.dart` passed.
- `flutter test` passed: 13 tests.
- `flutter build apk --release` passed and produced `build\app\outputs\flutter-apk\app-release.apk`.
- APK copied to `C:\Users\рс\Desktop\Soobshio-release.apk`.

## Known Blockers

- Full Ruff on touched backend files still reports pre-existing project rules in `reports.py`
  (`B008` for FastAPI `Depends`, `C901` complexity). These are not introduced by this pass.
- Android emulator/device UI verification was not run because `adb` is not available in PATH on this
  machine.

## Recommended Next Refactor Pass

1. Introduce a bounded runtime metrics queue to prevent per-request background task buildup.
2. Split `get_reports` filter parsing into small helpers and add tests around ordering/filter behavior.
3. Move map geocoding enrichment off the request path where possible.
4. Add screenshot or device-level UI verification once `adb`/emulator access is available.
