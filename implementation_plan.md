# Implementation Plan - City Pulse Updates

This plan outlines the implementation steps to fulfill all remaining requirements for City Pulse, including styling, functionality, map animations, and data populating.

## Proposed Changes

### Frontend Components

#### [MODIFY] [map_screen.dart](file:///c:/Soobshio_project/services/Frontend/lib/screens/map_screen.dart)
- Update dock menu icons: Use distinct icons for AI Assistant (`Icons.support_agent_rounded` or `Icons.chat_bubble_rounded`) and Daily Digest (`Icons.newspaper_rounded` or `Icons.summarize_rounded`).
- Implement `_highlightPolygonPoints` and `_highlightPolygonOpacity` state variables, and add an animated `PolygonLayer` in `FlutterMap` to draw selected districts with a 5-second fade-out/dissolve animation.
- Reset the inactivity timer when tapping the map.

#### [MODIFY] [map_filter_panel.dart](file:///c:/Soobshio_project/services/Frontend/lib/screens/map/widgets/map_filter_panel.dart)
- Reduce spacing and padding in expanded mode to make the filter panel height significantly smaller when opened.

#### [MODIFY] [daily_digest_ticker.dart](file:///c:/Soobshio_project/services/Frontend/lib/screens/map/widgets/daily_digest_ticker.dart)
- Dismiss/hide the running ticker after completing exactly 2 scrolling passes.
- Save a session-level flag so it only runs once per app session (doesn't repeat on back navigation).
- Style the ticker background, text, and icons to dynamically match light/dark app themes.

#### [MODIFY] [ai_digest_screen.dart](file:///c:/Soobshio_project/services/Frontend/lib/screens/ai_digest_screen.dart)
- Redesign `_buildReportTile` cards to look like lost & found screen cards (glassmorphic container with 3D category badges and clear spacing).

#### [MODIFY] [monitor_splash_screen.dart](file:///c:/Soobshio_project/services/Frontend/lib/screens/monitor_splash_screen.dart)
- Upgrade the center scanning circle with sci-fi golden and success green rotating nested rings.
- Fetch real latest signals from the `/map/feed` endpoint on startup and display them in the marquee string at the bottom.

## Verification Plan

### Automated Tests
- Run `flutter analyze` and `flutter test` to ensure there are no compilation errors or broken features.

### Manual Verification
- Launch the application and observe the upgraded sci-fi splash screen displaying real city signals in the ticker.
- Move the map, select a neighborhood filter, and confirm the animated polygon dissolves in 5 seconds.
- Verify the running ticker at the top fades away after 2 passes.
- Verify distinct icons in the assistant dock and map menus.
