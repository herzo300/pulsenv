
Deno.serve(async (req) => {
  return new Response(`<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Пульс Города - Карта жалоб</title>
  <meta name="theme-color" content="#0d9488">
  <link rel="preconnect" href="https://unpkg.com" crossorigin>
  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  
  <!-- Leaflet -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css" />
  
  <style>
    :root {
      --bg: #ffffff;
      --surface: #f8fafc;
      --text: #0f172a;
      --text-secondary: #64748b;
      --border: #e2e8f0;
      --primary: #0d9488;
      --danger: #dc2626;
      --success: #10b981;
      --warning: #f59e0b;
    }
    
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.4;
    }
    
    #map {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: 1;
    }
    
    /* Header */
    .header {
      position: fixed;
      top: 0; left: 0; right: 0;
      height: 54px;
      background: rgba(255,255,255,0.95);
      backdrop-filter: blur(10px);
      border-bottom: 1px solid var(--border);
      z-index: 1000;
      display: flex;
      align-items: center;
      padding: 0 12px;
      gap: 12px;
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-left: 8px;
    }

    .quick-link {
      width: 34px;
      height: 34px;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: #ffffff;
      color: var(--primary);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      text-decoration: none;
      transition: transform 0.2s ease, box-shadow 0.2s ease, background-color 0.2s ease;
      box-shadow: 0 2px 10px rgba(2, 6, 23, 0.08);
    }

    .quick-link:hover {
      transform: translateY(-1px);
      background: #f8fafc;
      box-shadow: 0 4px 16px rgba(2, 6, 23, 0.14);
    }
    
    .logo {
      display: flex;
      align-items: center;
      gap: 6px;
      font-weight: 700;
      font-size: 15px;
      color: var(--primary);
    }
    
    .logo-icon {
      width: 26px;
      height: 26px;
      background: linear-gradient(135deg, var(--primary), #14b8a6);
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 14px;
    }
    
    /* Stats Bar */
    .stats-bar {
      display: flex;
      gap: 8px;
      margin-left: auto;
    }
    
    .stat-item {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 4px 10px;
      background: var(--surface);
      border-radius: 8px;
      font-size: 11px;
      min-width: 50px;
    }
    
    .stat-item .value {
      font-weight: 700;
      font-size: 14px;
      color: var(--primary);
    }
    
    .stat-item .label {
      color: var(--text-secondary);
      font-size: 9px;
      text-transform: uppercase;
    }
    
    .stat-item.emergency .value {
      color: var(--danger);
    }
    
    /* Live indicator */
    .live-indicator {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 10px;
      color: var(--success);
      font-weight: 600;
    }
    
    .live-dot {
      width: 6px;
      height: 6px;
      background: var(--success);
      border-radius: 50%;
      animation: pulse 2s infinite;
    }
    
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(1.2); }
    }
    
    /* Filter Panel */
    .filter-panel {
      position: fixed;
      top: 54px;
      left: 0; right: 0;
      background: rgba(255,255,255,0.95);
      backdrop-filter: blur(10px);
      border-bottom: 1px solid var(--border);
      z-index: 999;
      padding: 6px 8px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    
    .filter-row {
      display: flex;
      gap: 4px;
      overflow-x: auto;
      scrollbar-width: none;
      padding: 2px 0;
    }
    
    .filter-row::-webkit-scrollbar { display: none; }
    
    /* Day filters */
    .day-btn {
      padding: 4px 10px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 14px;
      font-size: 11px;
      font-weight: 500;
      color: var(--text-secondary);
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
    }
    
    .day-btn:hover { background: #f1f5f9; }
    
    .day-btn.active {
      background: var(--primary);
      border-color: var(--primary);
      color: white;
    }
    
    /* Category filters */
    .filter-btn {
      padding: 4px 8px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 14px;
      font-size: 13px;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
      display: flex;
      align-items: center;
      gap: 2px;
    }
    
    .filter-btn:hover { background: #f1f5f9; }
    
    .filter-btn.active {
      background: var(--primary);
      border-color: var(--primary);
      color: white;
    }
    
    .filter-btn[data-filter="ЧП"] {
      border-color: var(--danger);
    }
    
    .filter-btn[data-filter="ЧП"].active {
      background: var(--danger);
      border-color: var(--danger);
      animation: emergency-glow 1.5s infinite;
    }
    
    @keyframes emergency-glow {
      0%, 100% { box-shadow: 0 0 0 0 rgba(220,38,38,0.4); }
      50% { box-shadow: 0 0 0 4px rgba(220,38,38,0); }
    }
    
    .filter-btn .cat-label {
      font-size: 10px;
      font-weight: 500;
    }
    
    /* Marker styles */
    .marker-pin {
      width: 28px;
      height: 28px;
      border-radius: 50% 50% 50% 0;
      background: white;
      border: 3px solid;
      transform: rotate(-45deg);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }
    
    .marker-pin.status-open { background: #fef2f2; }
    .marker-pin.status-in_progress { background: #fef9c3; }
    .marker-pin.status-resolved { background: #d1fae5; }
    
    .marker-pulse {
      position: absolute;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      top: -6px;
      left: -6px;
      animation: marker-pulse 2s infinite;
    }
    
    @keyframes marker-pulse {
      0% { transform: scale(0.8); opacity: 0.7; }
      100% { transform: scale(1.5); opacity: 0; }
    }
    
    /* Popup styles */
    .leaflet-popup-content-wrapper {
      padding: 0;
      border-radius: 12px;
      box-shadow: 0 8px 30px rgba(0,0,0,0.12);
    }
    
    .leaflet-popup-content { margin: 0; width: auto !important; }
    .leaflet-popup-tip { background: white; }
    
    .popup-card {
      padding: 12px;
      min-width: 220px;
      background: white;
      border-radius: 12px;
    }
    
    .popup-card.compact { padding: 10px; }
    
    .popup-header {
      display: flex;
      gap: 8px;
      align-items: flex-start;
      margin-bottom: 8px;
    }
    
    .popup-icon {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 16px;
      flex-shrink: 0;
    }
    
    .popup-title {
      flex: 1;
      min-width: 0;
    }
    
    .popup-title h3 {
      font-size: 13px;
      font-weight: 600;
      color: var(--text);
      margin-bottom: 3px;
      line-height: 1.3;
    }
    
    .popup-status {
      font-size: 10px;
      padding: 2px 6px;
      border-radius: 10px;
      font-weight: 500;
    }
    
    .popup-status.open { background: #fee2e2; color: #dc2626; }
    .popup-status.in_progress { background: #fef3c7; color: #d97706; }
    .popup-status.resolved { background: #d1fae5; color: #059669; }
    .popup-status.pending { background: #e0e7ff; color: #4f46e5; }
    
    .popup-desc {
      font-size: 11px;
      color: var(--text-secondary);
      margin-bottom: 8px;
      line-height: 1.4;
    }
    
    .popup-addr {
      font-size: 11px;
      color: var(--text-secondary);
      margin-bottom: 8px;
    }
    
    .popup-footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 11px;
      color: var(--text-secondary);
    }
    
    .popup-supporters { color: #ef4444; }
    
    /* Add button */
    .add-btn {
      position: fixed;
      bottom: 70px;
      right: 12px;
      width: 48px;
      height: 48px;
      background: linear-gradient(135deg, var(--primary), #14b8a6);
      border: none;
      border-radius: 50%;
      color: white;
      font-size: 24px;
      cursor: pointer;
      z-index: 1000;
      box-shadow: 0 4px 20px rgba(13,148,136,0.4);
      transition: all 0.3s;
    }
    
    .add-btn:hover {
      transform: scale(1.1);
      box-shadow: 0 6px 25px rgba(13,148,136,0.5);
    }
    
    .add-btn:active { transform: scale(0.95); }
    
    /* Splash */
    .splash {
      position: fixed;
      inset: 0;
      background: linear-gradient(135deg, var(--primary) 0%, #14b8a6 100%);
      z-index: 9999;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      color: white;
      transition: opacity 0.5s, visibility 0.5s;
    }

    .splash::before {
      content: '';
      position: absolute;
      inset: 0;
      background:
        radial-gradient(circle at 20% 20%, rgba(255,255,255,0.18), transparent 42%),
        radial-gradient(circle at 80% 10%, rgba(255,255,255,0.13), transparent 40%),
        radial-gradient(circle at 50% 95%, rgba(2,6,23,0.2), transparent 50%);
      pointer-events: none;
    }
    
    .splash.hidden {
      opacity: 0;
      visibility: hidden;
    }
    
    .splash-logo {
      width: 110px;
      height: 110px;
      border-radius: 999px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(255,255,255,0.18);
      border: 1px solid rgba(255,255,255,0.36);
      font-size: 52px;
      margin-bottom: 14px;
      box-shadow: 0 14px 40px rgba(15, 23, 42, 0.2);
      animation: pulseLogo 1.8s ease-in-out infinite;
    }
    
    @keyframes pulseLogo {
      0%, 100% { transform: scale(1); }
      50% { transform: scale(1.08); }
    }
    
    .splash-title {
      font-size: 22px;
      font-weight: 700;
      margin-bottom: 4px;
    }
    
    .splash-subtitle {
      font-size: 13px;
      opacity: 0.8;
      margin-bottom: 8px;
    }

    .splash-status {
      font-size: 12px;
      opacity: 0.9;
      min-height: 18px;
      margin-top: 6px;
      text-align: center;
      padding: 0 16px;
    }
    
    .splash-loader {
      margin-top: 24px;
      width: 40px;
      height: 40px;
      border: 3px solid rgba(255,255,255,0.3);
      border-top-color: white;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }

    .splash-start {
      margin-top: 14px;
      padding: 8px 14px;
      border-radius: 999px;
      border: 1px solid rgba(255,255,255,0.45);
      background: rgba(255,255,255,0.16);
      color: #fff;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      transition: background-color 0.2s ease, transform 0.2s ease;
    }

    .splash-start:hover {
      background: rgba(255,255,255,0.24);
      transform: translateY(-1px);
    }

    .splash-ripple {
      position: absolute;
      width: 12px;
      height: 12px;
      border-radius: 999px;
      border: 2px solid rgba(255,255,255,0.65);
      pointer-events: none;
      transform: translate(-50%, -50%) scale(0.2);
      animation: rippleOut 0.8s ease-out forwards;
    }

    @keyframes rippleOut {
      to {
        opacity: 0;
        transform: translate(-50%, -50%) scale(8);
      }
    }
    
    @keyframes spin { to { transform: rotate(360deg); } }
    
    /* Responsive */
    @media (max-width: 480px) {
      .header { height: 48px; padding: 0 8px; gap: 6px; }
      .logo { font-size: 12px; min-width: 0; }
      .logo span { max-width: 110px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .logo-icon { width: 22px; height: 22px; font-size: 12px; }
      .stats-bar { gap: 4px; }
      .stat-item { padding: 2px 6px; min-width: 40px; }
      .stat-item .value { font-size: 12px; }
      .stat-item .label { font-size: 8px; }
      .live-indicator { display: none; }
      .header-actions { margin-left: 0; gap: 4px; }
      .quick-link { width: 30px; height: 30px; }
      .filter-panel { top: 48px; padding: 4px 6px; }
      .add-btn { bottom: 60px; width: 44px; height: 44px; font-size: 22px; }
    }

    @media (prefers-reduced-motion: reduce) {
      .splash-logo, .live-dot, .splash-loader, .marker-pulse {
        animation: none !important;
      }
      * {
        scroll-behavior: auto !important;
      }
    }
  
    /* Map Pulse */
    .city-pulse-map {
      position: fixed;
      top: 60px;
      left: 50%;
      transform: translateX(-50%);
      z-index: 1000;
      background: rgba(255,255,255,0.95);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 5px 15px;
      display: flex;
      align-items: center;
      gap: 10px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.1);
      border: 1px solid var(--border);
    }
    #mapPulseCanvas {
      width: 100px;
      height: 30px;
    }
    .pulse-stats {
      display: flex;
      flex-direction: column;
      font-size: 10px;
      font-weight: 600;
      color: var(--primary);
    }
    
    /* Popup Actions */
    .popup-actions {
      display: flex;
      gap: 5px;
      margin-top: 8px;
      border-top: 1px solid var(--border);
      padding-top: 8px;
    }
    .popup-btn {
      flex: 1;
      padding: 4px 0;
      border: 1px solid var(--border);
      background: var(--surface);
      border-radius: 6px;
      font-size: 11px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      transition: all 0.2s;
    }
    .popup-btn:hover {
      background: #f1f5f9;
    }
    .popup-btn.join-btn {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
    }
    .popup-btn.join-btn:hover {
      background: #0f766e;
    }

    /* Bottom Sheet */
    .bottom-sheet {
      position: fixed;
      inset: 0;
      z-index: 2000;
      pointer-events: none;
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
    }
    
    .sheet-overlay {
      position: absolute;
      inset: 0;
      background: rgba(15, 23, 42, 0.4);
      backdrop-filter: blur(4px);
      opacity: 0;
      transition: opacity 0.3s ease;
      pointer-events: none;
    }
    
    .sheet-content {
      position: relative;
      background: #ffffff;
      border-radius: 24px 24px 0 0;
      padding: 0 20px 24px;
      max-height: 85vh;
      display: flex;
      flex-direction: column;
      transform: translateY(100%);
      transition: transform 0.4s cubic-bezier(0.32, 0.72, 0, 1);
      pointer-events: auto;
      box-shadow: 0 -8px 40px rgba(0,0,0,0.12);
    }
    
    .bottom-sheet.open .sheet-overlay {
      opacity: 1;
      pointer-events: auto;
    }
    
    .bottom-sheet.open .sheet-content {
      transform: translateY(0);
    }
    
    .sheet-drag-handle {
      display: flex;
      justify-content: center;
      padding: 12px 0;
      cursor: grab;
      margin-bottom: 4px;
    }
    
    .sheet-drag-handle span {
      width: 40px;
      height: 4px;
      border-radius: 4px;
      background: #cbd5e1;
    }
    
    .sheet-header {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      margin-bottom: 16px;
    }
    
    .sheet-icon {
      width: 48px;
      height: 48px;
      border-radius: 12px;
      background: var(--surface);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      flex-shrink: 0;
    }
    
    .sheet-title-container {
      flex: 1;
      min-width: 0;
    }
    
    .sheet-title {
      font-size: 18px;
      font-weight: 700;
      color: var(--text);
      margin-bottom: 6px;
      line-height: 1.3;
    }
    
    .sheet-status {
      display: inline-block;
      font-size: 12px;
      padding: 4px 10px;
      border-radius: 12px;
      font-weight: 600;
    }
    
    .sheet-status.open { background: #fee2e2; color: #dc2626; }
    .sheet-status.in_progress { background: #fef3c7; color: #d97706; }
    .sheet-status.resolved { background: #d1fae5; color: #059669; }
    .sheet-status.pending { background: #e0e7ff; color: #4f46e5; }
    
    .sheet-close {
      width: 32px;
      height: 32px;
      border-radius: 16px;
      background: var(--surface);
      border: none;
      font-size: 20px;
      color: var(--text-secondary);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: background 0.2s;
    }
    
    .sheet-close:hover {
      background: #e2e8f0;
    }
    
    .sheet-body {
      overflow-y: auto;
      flex: 1;
      padding-right: 4px;
      scrollbar-width: thin;
    }
    
    .sheet-address, .sheet-time {
      font-size: 14px;
      color: var(--text-secondary);
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    
    .sheet-desc {
      font-size: 15px;
      color: var(--text);
      line-height: 1.6;
      margin: 16px 0;
      padding: 16px;
      background: var(--surface);
      border-radius: 16px;
      border: 1px solid var(--border);
    }
    
    .sheet-actions {
      display: flex;
      gap: 12px;
      margin: 20px 0;
    }
    
    .sheet-action-btn {
      flex: 1;
      padding: 12px;
      border: 1px solid var(--border);
      background: white;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: all 0.2s;
    }
    
    .sheet-action-group {
      display: flex;
      gap: 8px;
      flex: 1;
    }
    
    .sheet-action-btn:hover {
      background: var(--surface);
    }
    
    .sheet-action-btn.primary {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
      flex: 1.5;
    }
    
    .sheet-action-btn.primary:hover {
      background: #0f766e;
    }
    
    .sheet-action-btn .count {
      font-weight: 700;
      opacity: 0.9;
    }
    
    .sheet-comments-section {
      margin-top: 24px;
      border-top: 1px solid var(--border);
      padding-top: 20px;
    }
    
    .sheet-section-title {
      font-size: 16px;
      font-weight: 700;
      color: var(--text);
      margin-bottom: 16px;
    }
    
    .sheet-comments-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    
    .sheet-comment {
      padding: 12px 16px;
      background: var(--surface);
      border-radius: 16px;
      border-bottom-left-radius: 4px;
    }
    
    .sheet-comment-header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 6px;
      font-size: 12px;
    }
    
    .sheet-comment-author {
      font-weight: 600;
      color: var(--text);
    }
    
    .sheet-comment-date {
      color: var(--text-secondary);
    }
    
    .sheet-comment-text {
      font-size: 14px;
      color: var(--text);
      line-height: 1.4;
    }
    
    .sheet-gallery {
      display: flex;
      gap: 8px;
      overflow-x: auto;
      margin: 16px 0;
      padding-bottom: 8px;
      scrollbar-width: none;
    }
    
    .sheet-gallery img {
      height: 120px;
      border-radius: 12px;
      object-fit: cover;
      flex-shrink: 0;
    }

  </style>
</head>
<body>
  <!-- Splash -->
  <div class="splash" id="splash">
    <div class="splash-logo">🗺️</div>
    <div class="splash-title">Пульс Города</div>
    <div class="splash-subtitle">Нижневартовск</div>
    <div class="splash-status" id="splash-status">Подключаем карту...</div>
    <div class="splash-loader"></div>
    <button class="splash-start" id="splash-start-btn" type="button">Пропустить ожидание</button>
  </div>
  
  <!-- Header -->
  <header class="header">
    <div class="logo">
      <div class="logo-icon">🗺️</div>
      <span>Пульс Города</span>
    </div>
    
    <div class="stats-bar">
      <div class="stat-item">
        <span class="value" id="stat-today">0</span>
        <span class="label">День</span>
      </div>
      <div class="stat-item">
        <span class="value" id="stat-month">0</span>
        <span class="label">Месяц</span>
      </div>
      <div class="stat-item">
        <span class="value" id="stat-year">0</span>
        <span class="label">Год</span>
      </div>
      <div class="stat-item">
        <span class="value" id="complaint-count">0</span>
        <span class="label">Всего</span>
      </div>
    </div>
    
    <div class="live-indicator">
      <div class="live-dot"></div>
      <span>LIVE</span>
    </div>

    <div class="header-actions">
      <a class="quick-link" href="info.html" title="Открыть инфографику" aria-label="Открыть инфографику">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M3 3v18h18"/>
          <path d="M7 14l4-4 3 3 5-6"/>
        </svg>
      </a>
    </div>
  </header>
  
  <!-- Filter Panel -->
  
  <div id="city-pulse-container" class="city-pulse-map">
    <canvas id="mapPulseCanvas"></canvas>
    <div class="pulse-stats">
      <span><span id="pulse-bpm">72</span> BPM</span>
      <span id="pulse-mood">Спокойно</span>
    </div>
  </div>

  <div class="filter-panel" style="top: 105px;">
    <!-- Day filters -->
    <div class="filter-row" id="day-filters">
      <button class="day-btn active" data-day="all">Все</button>
      <button class="day-btn" data-day="today">Сегодня</button>
      <button class="day-btn" data-day="3days">3 дня</button>
      <button class="day-btn" data-day="week">Неделя</button>
      <button class="day-btn" data-day="month">Месяц</button>
    </div>
    
    <!-- Category filters -->
    <div class="filter-row" id="category-filters">
      <button class="filter-btn active" data-filter="all">Все</button>
      <button class="filter-btn" data-filter="ЧП">🚨<span class="cat-label">ЧП</span></button>
      <button class="filter-btn" data-filter="ЖКХ">🏠</button>
      <button class="filter-btn" data-filter="Дороги">🛣️</button>
      <button class="filter-btn" data-filter="Благоустройство">🌳</button>
      <button class="filter-btn" data-filter="Транспорт">🚌</button>
      <button class="filter-btn" data-filter="Освещение">💡</button>
      <button class="filter-btn" data-filter="Газоснабжение">🔥</button>
      <button class="filter-btn" data-filter="Водоснабжение и канализация">💧</button>
      <button class="filter-btn" data-filter="Отопление">🌡️</button>
      <button class="filter-btn" data-filter="Мусор">🗑️</button>
      <button class="filter-btn" data-filter="Снег/Наледь">❄️</button>
      <button class="filter-btn" data-filter="Детские площадки">🎠</button>
      <button class="filter-btn" data-filter="Парковки">🅿️</button>
      <button class="filter-btn" data-filter="Безопасность">🛡️</button>
      <button class="filter-btn" data-filter="Медицина">🏥</button>
      <button class="filter-btn" data-filter="Экология">🌿</button>
      <button class="filter-btn" data-filter="Прочее">📌</button>
    </div>
  </div>
  
  <!-- Map -->
  <div id="map"></div>
  
  <!-- Add Button -->
  <button class="add-btn" id="add-complaint-btn">+</button>

  <!-- Marker Bottom Sheet -->
  <div class="bottom-sheet" id="marker-bottom-sheet">
    <div class="sheet-overlay" id="sheet-overlay"></div>
    <div class="sheet-content" id="sheet-content">
      <div class="sheet-drag-handle">
        <span></span>
      </div>
      <div class="sheet-header">
        <div class="sheet-icon" id="sheet-icon">🚨</div>
        <div class="sheet-title-container">
          <h2 class="sheet-title" id="sheet-title">Заголовок</h2>
          <span class="sheet-status" id="sheet-status">Открыта</span>
        </div>
        <button class="sheet-close" id="sheet-close">×</button>
      </div>
      <div class="sheet-body">
        <div class="sheet-address" id="sheet-address">📍 Адрес</div>
        <div class="sheet-time" id="sheet-time">Только что</div>
        <div class="sheet-desc" id="sheet-desc">Описание проблемы...</div>
        
        <div class="sheet-gallery" id="sheet-gallery" style="display:none;">
          <!-- Images will be injected here -->
        </div>

        <div class="sheet-actions">
          <button class="sheet-action-btn primary" id="sheet-btn-join">
            <span class="emoji">🙋</span>Поддержать <span class="count" id="sheet-count-join">0</span>
          </button>
          <div class="sheet-action-group">
            <button class="sheet-action-btn" id="sheet-btn-like">
              <span class="emoji">👍</span><span class="count" id="sheet-count-like">0</span>
            </button>
            <button class="sheet-action-btn" id="sheet-btn-dislike">
              <span class="emoji">👎</span><span class="count" id="sheet-count-dislike">0</span>
            </button>
          </div>
        </div>
        
        <div class="sheet-comments-section">
          <h3 class="sheet-section-title">Комментарии (<span id="sheet-comments-count">0</span>)</h3>
          <div class="sheet-comments-list" id="sheet-comments-list">
            <!-- Comments injected here -->
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Scripts -->
  <script defer src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script defer src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"></script>
  <script>/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * ПУЛЬС ГОРОДА - Карта жалоб Нижневартовска v2.1
 * Полный список категорий + ЧП | Счётчики день/месяц/год | HDBSCAN-like clustering
 * ═══════════════════════════════════════════════════════════════════════════════
 */

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const CONFIG = {
  center: [60.9366, 76.5594],
  zoom: 13,
  minZoom: 11,
  maxZoom: 18,
  
  supabase: {
    url: 'https://xpainxohbdoruakcijyq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc'
  },
  
  tiles: {
    light: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    attribution: '&copy; OSM &copy; CARTO'
  },
  
  newMarkerZoom: 16,
  popupDuration: 10000,
  returnDelay: 500
};

// ═══════════════════════════════════════════════════════════════════════════════
// FULL CATEGORIES LIST (from project analysis)
// ═══════════════════════════════════════════════════════════════════════════════

const CATEGORIES = {
  // Приоритетные категории (ЧП первым!)
  'ЧП': { icon: '🚨', color: '#dc2626', priority: 1 },
  
  // ЖКХ и инфраструктура
  'ЖКХ': { icon: '🏠', color: '#f97316', priority: 2 },
  'Дороги': { icon: '🛣️', color: '#ef4444', priority: 2 },
  'Благоустройство': { icon: '🌳', color: '#22c55e', priority: 3 },
  'Транспорт': { icon: '🚌', color: '#3b82f6', priority: 3 },
  'Освещение': { icon: '💡', color: '#eab308', priority: 3 },
  
  // Коммуникации
  'Газоснабжение': { icon: '🔥', color: '#f97316', priority: 1 },
  'Водоснабжение и канализация': { icon: '💧', color: '#0ea5e9', priority: 2 },
  'Отопление': { icon: '🌡️', color: '#f43f5e', priority: 2 },
  'Связь': { icon: '📡', color: '#6366f1', priority: 4 },
  
  // Мусор и экология
  'Мусор': { icon: '🗑️', color: '#84cc16', priority: 3 },
  'Бытовой мусор': { icon: '🗑️', color: '#84cc16', priority: 3 },
  'Экология': { icon: '🌿', color: '#10b981', priority: 3 },
  
  // Общественные пространства
  'Детские площадки': { icon: '🎠', color: '#ec4899', priority: 3 },
  'Спортивные площадки': { icon: '⚽', color: '#8b5cf6', priority: 4 },
  'Парки и скверы': { icon: '🌲', color: '#059669', priority: 4 },
  'Парковки': { icon: '🅿️', color: '#6366f1', priority: 4 },
  
  // Здания
  'Лифты и подъезды': { icon: '🏢', color: '#64748b', priority: 3 },
  'Строительство': { icon: '🚧', color: '#d97706', priority: 4 },
  
  // Безопасность и погода
  'Безопасность': { icon: '🛡️', color: '#dc2626', priority: 2 },
  'Снег/Наледь': { icon: '❄️', color: '#38bdf8', priority: 2 },
  
  // Социальные
  'Медицина': { icon: '🏥', color: '#14b8a6', priority: 2 },
  'Здравоохранение': { icon: '🏥', color: '#14b8a6', priority: 2 },
  'Образование': { icon: '🎓', color: '#8b5cf6', priority: 3 },
  'Социальная сфера': { icon: '👥', color: '#6366f1', priority: 4 },
  
  // Другие
  'Животные': { icon: '🐶', color: '#f59e0b', priority: 4 },
  'Торговля': { icon: '🛒', color: '#10b981', priority: 4 },
  'Трудовое право': { icon: '📄', color: '#64748b', priority: 4 },
  
  // По умолчанию
  'Прочее': { icon: '📌', color: '#64748b', priority: 5 }
};

// Основные категории для фильтров (компактный набор)
const MAIN_CATEGORIES = [
  'ЧП', 'ЖКХ', 'Дороги', 'Благоустройство', 'Транспорт', 'Освещение',
  'Мусор', 'Детские площадки', 'Парковки', 'Безопасность', 'Снег/Наледь',
  'Медицина', 'Экология', 'Прочее'
];

const STATUS_LABELS = {
  'open': 'Открыта',
  'in_progress': 'В работе',
  'resolved': 'Решена',
  'closed': 'Закрыта',
  'pending': 'На рассмотрении'
};

const DAY_FILTERS = [
  { id: 'all', label: 'Все' },
  { id: 'today', label: 'Сегодня' },
  { id: '3days', label: '3 дня' },
  { id: 'week', label: 'Неделя' },
  { id: 'month', label: 'Месяц' }
];

// ═══════════════════════════════════════════════════════════════════════════════
// APPLICATION STATE
// ═══════════════════════════════════════════════════════════════════════════════

const state = {
  map: null,
  supabase: null,
  markerCluster: null,
  markers: new Map(),
  complaints: [],
  currentCategoryFilter: 'all',
  currentDayFilter: 'all',
  realtimeSubscription: null,
  isLoading: true,
  savedView: null,
  autoReturnTimeout: null,
  stats: {
    today: 0,
    month: 0,
    year: 0,
    total: 0
  }
};

const SPLASH_MESSAGES = [
  'Подключаем карту...',
  'Загружаем обращения...',
  'Включаем live-обновления...',
  'Почти готово'
];

let splashMessageIndex = 0;
let splashMessageInterval = null;

// ═══════════════════════════════════════════════════════════════════════════════
// SUPABASE CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

async function initSupabase() {
  let supabaseLib = window.supabase;
  
  if (!supabaseLib || !supabaseLib.createClient) {
    setSplashStatus('Подключаем Supabase...');
    console.log('⏳ Loading Supabase...');
    try {
      await loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js');
      supabaseLib = window.supabase;
    } catch (e) {
      try {
        await loadScript('https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.min.js');
        supabaseLib = window.supabase;
      } catch (e2) {
      setSplashStatus('Работаем в демо-режиме');
      console.error('❌ Supabase load failed');
        return false;
      }
    }
  }
  
  if (!supabaseLib?.createClient) return false;
  
  state.supabase = supabaseLib.createClient(CONFIG.supabase.url, CONFIG.supabase.anonKey);
  setSplashStatus('Supabase подключен');
  console.log('✅ Supabase OK');
  return true;
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAP INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

function initMap() {
  if (typeof L === 'undefined') {
    document.getElementById('map').innerHTML = \`
      <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;background:#f8fafc;color:#475569;font-family:system-ui;padding:24px;text-align:center;">
        <div style="font-size:48px;margin-bottom:16px;">🗺️</div>
        <div style="font-size:16px;font-weight:600;">Карта не загрузилась</div>
        <button onclick="location.reload()" style="margin-top:16px;padding:10px 20px;background:#0d9488;color:white;border:none;border-radius:8px;cursor:pointer;">↻ Обновить</button>
      </div>\`;
    hideSplash();
    return false;
  }
  
  setSplashStatus('Инициализируем карту...');
  
  state.map = L.map('map', {
    center: CONFIG.center,
    zoom: CONFIG.zoom,
    minZoom: CONFIG.minZoom,
    maxZoom: CONFIG.maxZoom,
    zoomControl: true
  });
  
  L.tileLayer(CONFIG.tiles.light, {
    attribution: CONFIG.tiles.attribution,
    maxZoom: 19
  }).addTo(state.map);
  
  state.map.zoomControl.setPosition('bottomright');
  
  // HDBSCAN-like clustering
  state.markerCluster = L.markerClusterGroup({
    showCoverageOnHover: false,
    maxClusterRadius: (zoom) => Math.max(30, 80 - zoom * 4),
    spiderfyOnMaxZoom: true,
    disableClusteringAtZoom: 17,
    animate: true,
    animateAddingMarkers: true,
    iconCreateFunction: createClusterIcon,
    spiderfyDistanceMultiplier: 1.5,
    chunkedLoading: true
  });
  
  state.map.addLayer(state.markerCluster);
  setSplashStatus('Карта готова');
  console.log('✅ Map OK');
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARKER & CLUSTER CREATION
// ═══════════════════════════════════════════════════════════════════════════════

function createClusterIcon(cluster) {
  const count = cluster.getChildCount();
  const children = cluster.getAllChildMarkers();
  
  // Get dominant category and check for ЧП
  const catCounts = {};
  let hasEmergency = false;
  
  children.forEach(m => {
    const cat = m.complaintData?.category || 'Прочее';
    if (cat === 'ЧП') hasEmergency = true;
    catCounts[cat] = (catCounts[cat] || 0) + 1;
  });
  
  let maxCat = 'Прочее', maxCount = 0;
  Object.entries(catCounts).forEach(([cat, cnt]) => {
    if (cnt > maxCount) { maxCat = cat; maxCount = cnt; }
  });
  
  // ЧП cluster has priority color
  const color = hasEmergency ? '#dc2626' : (CATEGORIES[maxCat]?.color || '#64748b');
  let size = count > 25 ? 48 : count > 10 ? 42 : 36;
  
  return L.divIcon({
    html: \`<div style="background:\${color};width:\${size}px;height:\${size}px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:\${size > 42 ? 14 : 12}px;box-shadow:0 3px 12px \${color}66;\${hasEmergency ? 'animation:emergency-pulse 1s infinite;' : ''}">\${count}</div>\`,
    className: 'custom-cluster',
    iconSize: L.point(size, size)
  });
}

function createMarkerIcon(complaint) {
  const status = complaint.status || 'open';
  const cat = CATEGORIES[complaint.category] || CATEGORIES['Прочее'];
  const isEmergency = complaint.category === 'ЧП';
  
  return L.divIcon({
    className: 'custom-marker',
    html: \`
      <div class="marker-pulse" style="background:\${cat.color}33;\${isEmergency ? 'animation:emergency-pulse 1s infinite;' : ''}"></div>
      <div class="marker-pin status-\${status}" style="border-color:\${cat.color};">
        <span style="transform:rotate(45deg);font-size:14px;">\${cat.icon}</span>
      </div>\`,
    iconSize: [32, 32],
    iconAnchor: [16, 32],
    popupAnchor: [0, -32]
  });
}


// Popup creation was removed in favor of Bottom Sheet

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET UI LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

let currentComplaintId = null;

function openBottomSheet(complaint) {
  currentComplaintId = complaint.id;
  const sheet = document.getElementById('marker-bottom-sheet');
  const cat = CATEGORIES[complaint.category] || CATEGORIES['Прочее'];
  const isEmergency = complaint.category === 'ЧП';
  const status = complaint.status || 'open';
  
  // Update Header
  document.getElementById('sheet-icon').textContent = cat.icon;
  document.getElementById('sheet-icon').style.background = \`\${cat.color}22\`;
  document.getElementById('sheet-icon').style.color = cat.color;
  
  const titleEl = document.getElementById('sheet-title');
  titleEl.textContent = \`\${isEmergency ? '⚠️ ' : ''}\${complaint.summary || complaint.category}\`;
  if (isEmergency) titleEl.style.color = 'var(--danger)';
  else titleEl.style.color = 'var(--text)';
  
  const statusEl = document.getElementById('sheet-status');
  statusEl.textContent = STATUS_LABELS[status] || status;
  statusEl.className = \`sheet-status \${status}\`;
  
  // Update Body
  document.getElementById('sheet-address').textContent = complaint.address ? \`📍 \${complaint.address}\` : '📍 Нет адреса';
  document.getElementById('sheet-time').textContent = \`🕒 \${getTimeAgo(complaint.created_at)}\`;
  document.getElementById('sheet-desc').textContent = complaint.description || 'Описание не указано.';
  
  // Counters
  document.getElementById('sheet-count-join').textContent = complaint.supporters || 0;
  document.getElementById('sheet-count-like').textContent = complaint.likes_count || 0;
  document.getElementById('sheet-count-dislike').textContent = complaint.dislikes_count || 0;
  
  // Gallery
  const gallery = document.getElementById('sheet-gallery');
  if (complaint.images && complaint.images.length > 0) {
    gallery.style.display = 'flex';
    gallery.innerHTML = complaint.images.map(img => \`<img src="\${img}" alt="Фото проблемы" onclick="window.open('\${img}', '_blank')">\`).join('');
  } else {
    gallery.style.display = 'none';
  }
  
  // Open Sheet
  sheet.classList.add('open');
  loadComments(complaint.id);
  
  // Setup Buttons
  document.getElementById('sheet-btn-join').onclick = () => handleAction(complaint.id, 'join');
  document.getElementById('sheet-btn-like').onclick = () => handleAction(complaint.id, 'like');
  document.getElementById('sheet-btn-dislike').onclick = () => handleAction(complaint.id, 'dislike');
}

function closeBottomSheet() {
  const sheet = document.getElementById('marker-bottom-sheet');
  if (sheet) sheet.classList.remove('open');
  currentComplaintId = null;
}

function initBottomSheet() {
  const sheet = document.getElementById('marker-bottom-sheet');
  const overlay = document.getElementById('sheet-overlay');
  const closeBtn = document.getElementById('sheet-close');
  const dragHandle = document.querySelector('.sheet-drag-handle');
  const content = document.getElementById('sheet-content');
  
  if (!sheet) return;
  
  overlay.addEventListener('click', closeBottomSheet);
  closeBtn.addEventListener('click', closeBottomSheet);
  
  let startY, currentY;
  let isDragging = false;
  
  dragHandle.addEventListener('touchstart', (e) => {
    startY = e.touches[0].clientY;
    isDragging = true;
    content.style.transition = 'none';
  }, { passive: true });
  
  document.addEventListener('touchmove', (e) => {
    if (!isDragging) return;
    currentY = e.touches[0].clientY;
    const diff = currentY - startY;
    if (diff > 0) {
      content.style.transform = \`translateY(\${diff}px)\`;
    }
  }, { passive: true });
  
  document.addEventListener('touchend', (e) => {
    if (!isDragging) return;
    isDragging = false;
    content.style.transition = 'transform 0.4s cubic-bezier(0.32, 0.72, 0, 1)';
    
    if (currentY - startY > 80) {
      closeBottomSheet();
    }
    content.style.transform = '';
  });
}

async function loadComments(complaintId) {
  const list = document.getElementById('sheet-comments-list');
  const countEl = document.getElementById('sheet-comments-count');
  list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-secondary)">Загрузка комментариев...</div>';
  
  if (!state.supabase) return;
  
  try {
    const { data: comments, error } = await state.supabase
      .from('comments')
      .select('*')
      .eq('complaint_id', complaintId)
      .order('created_at', { ascending: false });
      
    if (error) throw error;
    
    countEl.textContent = comments.length;
    
    if (comments.length === 0) {
      list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-secondary)">Пока нет комментариев</div>';
      return;
    }
    
    list.innerHTML = comments.map(c => \`
      <div class="sheet-comment">
        <div class="sheet-comment-header">
          <span class="sheet-comment-author">\${c.author_name || 'Житель'}</span>
          <span class="sheet-comment-date">\${getTimeAgo(c.created_at)}</span>
        </div>
        <div class="sheet-comment-text">\${c.content}</div>
      </div>
    \`).join('');
    
  } catch (e) {
    console.error('Error loading comments', e);
    list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--danger)">Ошибка загрузки</div>';
  }
}

window.handleAction = async function(id, action) {
  if (!state.supabase) return;
  
  try {
    const { data: currentData } = await state.supabase
      .from('complaints')
      .select('supporters, likes_count, dislikes_count')
      .eq('id', id)
      .single();
      
    if (!currentData) return;
    
    let updates = {};
    if (action === 'join') updates.supporters = (currentData.supporters || 0) + 1;
    if (action === 'like') updates.likes_count = (currentData.likes_count || 0) + 1;
    if (action === 'dislike') updates.dislikes_count = (currentData.dislikes_count || 0) + 1;
    
    const { error } = await state.supabase
      .from('complaints')
      .update(updates)
      .eq('id', id);
      
    if (!error) {
      // Update local state
      const marker = state.markers.get(id);
      if (marker && marker.complaintData) {
        if (action === 'join') marker.complaintData.supporters = updates.supporters;
        if (action === 'like') marker.complaintData.likes = updates.likes_count;
        if (action === 'dislike') marker.complaintData.dislikes = updates.dislikes_count;
      }

      // Update bottom sheet if open
      if (currentComplaintId === id) {
        if (action === 'join') document.getElementById('sheet-count-join').textContent = updates.supporters;
        if (action === 'like') document.getElementById('sheet-count-like').textContent = updates.likes_count;
        if (action === 'dislike') document.getElementById('sheet-count-dislike').textContent = updates.dislikes_count;
      }
      
      // If joins >= 10, trigger collective email (via backend/supabase edge function)
      if (action === 'join' && updates.supporters === 10) {
        fetch('https://xpainxohbdoruakcijyq.supabase.co/functions/v1/api/collective-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ complaint_id: id })
        }).catch(e => console.error('Error triggering email', e));
      }
    }
  } catch (e) {
    console.error('Action error', e);
  }
};
function addMarker(complaint, animate = false) {
  if (!complaint.lat || !complaint.lng) return null;
  if (state.markers.has(complaint.id)) return state.markers.get(complaint.id);
  
  const marker = L.marker([complaint.lat, complaint.lng], {
    icon: createMarkerIcon(complaint)
  });
  
  marker.on('click', () => {
    openBottomSheet(complaint);
    state.map.setView([complaint.lat, complaint.lng], Math.max(state.map.getZoom(), 15), {
      animate: true,
      duration: 0.5
    });
  });
  marker.complaintData = complaint;
  state.markers.set(complaint.id, marker);
  
  if (matchesFilters(complaint)) {
    state.markerCluster.addLayer(marker);
    
    if (animate) {
      focusOnNewMarker(marker, complaint);
    }
  }
  
  return marker;
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-ZOOM & POPUP FOR NEW MARKERS
// ═══════════════════════════════════════════════════════════════════════════════

function focusOnNewMarker(marker, complaint) {
  state.savedView = {
    center: state.map.getCenter(),
    zoom: state.map.getZoom()
  };
  
  if (state.autoReturnTimeout) {
    clearTimeout(state.autoReturnTimeout);
  }
  
  state.map.flyTo([complaint.lat, complaint.lng], CONFIG.newMarkerZoom, {
    duration: 1.2,
    easeLinearity: 0.25
  });
  
  setTimeout(() => {
    openBottomSheet(complaint);
    const isEmergency = complaint.category === 'ЧП';
    showNotification(\`\${isEmergency ? '🚨 ЧП: ' : '🆕 '}\${complaint.summary || complaint.category}\`, isEmergency ? 'emergency' : 'new');
  }, 1300);
  
  state.autoReturnTimeout = setTimeout(() => {
    closeBottomSheet();
    
    setTimeout(() => {
      if (state.savedView) {
        state.map.flyTo(state.savedView.center, state.savedView.zoom, {
          duration: 1,
          easeLinearity: 0.25
        });
        state.savedView = null;
      }
    }, CONFIG.returnDelay);
  }, CONFIG.popupDuration);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS CALCULATION
// ═══════════════════════════════════════════════════════════════════════════════

function calculateStats() {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const yearStart = new Date(now.getFullYear(), 0, 1);
  
  state.stats = {
    today: 0,
    month: 0,
    year: 0,
    total: state.complaints.length
  };
  
  state.complaints.forEach(c => {
    const created = new Date(c.created_at);
    if (created >= todayStart) state.stats.today++;
    if (created >= monthStart) state.stats.month++;
    if (created >= yearStart) state.stats.year++;
  });
  
  console.log(\`📊 Stats: today=\${state.stats.today}, month=\${state.stats.month}, year=\${state.stats.year}, total=\${state.stats.total}\`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA LOADING
// ═══════════════════════════════════════════════════════════════════════════════

async function loadComplaints() {
  console.log('📥 Loading...');
  setSplashStatus('Загружаем обращения...');
  
  if (state.supabase) {
    try {
      const { data, error } = await state.supabase
        .from('complaints')
        .select('*')
        .not('lat', 'is', null)
        .not('lng', 'is', null)
        .order('created_at', { ascending: false })
        .limit(1000);
      
      if (error) {
        console.error('❌ Load error:', error);
        return loadDemoComplaints();
      }
      
      console.log(\`✅ Loaded \${data.length} complaints\`);
      state.complaints = data;
      data.forEach(c => addMarker(c));
      calculateStats();
      updateUI();
      return data;
    } catch (err) {
      console.error('❌ Exception:', err);
      return loadDemoComplaints();
    }
  }
  return loadDemoComplaints();
}

function loadDemoComplaints() {
  console.log('📦 Demo mode');
  const now = Date.now();
  const demoData = [
    { id: 'd1', summary: 'Прорыв трубы на улице', category: 'ЧП', status: 'open', lat: 60.9400, lng: 76.5650, address: 'ул. Ленина, 45', supporters: 45, created_at: new Date(now - 3600000).toISOString() },
    { id: 'd2', summary: 'Яма на дороге', category: 'Дороги', status: 'open', lat: 60.9380, lng: 76.5550, address: 'ул. Мира, 22', supporters: 15, created_at: new Date(now).toISOString() },
    { id: 'd3', summary: 'Протечка в подъезде', category: 'ЖКХ', status: 'in_progress', lat: 60.9350, lng: 76.5500, address: 'ул. Нефтяников, 10', supporters: 8, created_at: new Date(now - 86400000).toISOString() },
    { id: 'd4', summary: 'Сломанные качели', category: 'Детские площадки', status: 'open', lat: 60.9360, lng: 76.5700, address: 'ул. Чапаева, 5', supporters: 23, created_at: new Date(now - 172800000).toISOString() },
    { id: 'd5', summary: 'Не горит фонарь', category: 'Освещение', status: 'resolved', lat: 60.9320, lng: 76.5480, address: 'ул. 60 лет Октября', supporters: 5, created_at: new Date(now - 604800000).toISOString() },
    { id: 'd6', summary: 'Мусор у контейнеров', category: 'Мусор', status: 'open', lat: 60.9410, lng: 76.5600, address: 'мкр. 10П', supporters: 31, created_at: new Date(now - 2592000000).toISOString() },
    { id: 'd7', summary: 'Снег не убран', category: 'Снег/Наледь', status: 'open', lat: 60.9330, lng: 76.5520, address: 'пр. Победы', supporters: 12, created_at: new Date(now - 86400000 * 15).toISOString() }
  ];
  
  state.complaints = demoData;
  demoData.forEach(c => addMarker(c));
  calculateStats();
  updateUI();
  return demoData;
}

// ═══════════════════════════════════════════════════════════════════════════════
// REALTIME SUBSCRIPTION
// ═══════════════════════════════════════════════════════════════════════════════

function subscribeToRealtime() {
  if (!state.supabase) return;
  
  console.log('📡 Subscribing to realtime...');
  
  state.realtimeSubscription = state.supabase
    .channel('complaints-realtime')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'complaints' }, (payload) => {
      console.log('🆕 New:', payload.new);
      handleNewComplaint(payload.new);
    })
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'complaints' }, (payload) => {
      handleUpdatedComplaint(payload.new);
    })
    .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'complaints' }, (payload) => {
      handleDeletedComplaint(payload.old);
    })
    .subscribe((status) => {
      console.log(\`📡 Realtime: \${status}\`);
    });
}

function handleNewComplaint(complaint) {
  state.complaints.unshift(complaint);
  addMarker(complaint, true);
  calculateStats();
  updateUI();
}

function handleUpdatedComplaint(complaint) {
  const idx = state.complaints.findIndex(c => c.id === complaint.id);
  if (idx !== -1) state.complaints[idx] = complaint;
  
  const marker = state.markers.get(complaint.id);
  if (marker) {
    marker.setIcon(createMarkerIcon(complaint));
    marker.complaintData = complaint;
    
    if (currentComplaintId === complaint.id) {
      openBottomSheet(complaint);
    }
  }
}

function handleDeletedComplaint(complaint) {
  state.complaints = state.complaints.filter(c => c.id !== complaint.id);
  const marker = state.markers.get(complaint.id);
  if (marker) {
    state.markerCluster.removeLayer(marker);
    state.markers.delete(complaint.id);
  }
  calculateStats();
  updateUI();
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTERS
// ═══════════════════════════════════════════════════════════════════════════════

function matchesFilters(complaint) {
  if (state.currentCategoryFilter !== 'all' && complaint.category !== state.currentCategoryFilter) {
    return false;
  }
  
  if (state.currentDayFilter !== 'all') {
    const created = new Date(complaint.created_at);
    const now = new Date();
    const diffDays = (now - created) / (1000 * 60 * 60 * 24);
    
    switch (state.currentDayFilter) {
      case 'today': if (diffDays > 1) return false; break;
      case '3days': if (diffDays > 3) return false; break;
      case 'week': if (diffDays > 7) return false; break;
      case 'month': if (diffDays > 30) return false; break;
    }
  }
  
  return true;
}

function applyFilters() {
  state.markerCluster.clearLayers();
  
  state.complaints.forEach(complaint => {
    const marker = state.markers.get(complaint.id);
    if (marker && matchesFilters(complaint)) {
      state.markerCluster.addLayer(marker);
    }
  });
  
  updateUI();
}

function initFilters() {
  const catPanel = document.getElementById('category-filters');
  if (catPanel) {
    catPanel.addEventListener('click', (e) => {
      const btn = e.target.closest('.filter-btn');
      if (!btn) return;
      
      state.currentCategoryFilter = btn.dataset.filter;
      catPanel.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      applyFilters();
    });
  }
  
  const dayPanel = document.getElementById('day-filters');
  if (dayPanel) {
    dayPanel.addEventListener('click', (e) => {
      const btn = e.target.closest('.day-btn');
      if (!btn) return;
      
      state.currentDayFilter = btn.dataset.day;
      dayPanel.querySelectorAll('.day-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      applyFilters();
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

function updateUI() {
  const filteredCount = state.complaints.filter(matchesFilters).length;
  
  // Update main counter
  const countEl = document.getElementById('complaint-count');
  if (countEl) countEl.textContent = filteredCount;
  
  // Update stats counters
  const todayEl = document.getElementById('stat-today');
  const monthEl = document.getElementById('stat-month');
  const yearEl = document.getElementById('stat-year');
  
  if (todayEl) todayEl.textContent = state.stats.today;
  if (monthEl) monthEl.textContent = state.stats.month;
  if (yearEl) yearEl.textContent = state.stats.year;
}

function hideSplash() {
  stopSplashTicker();
  const splash = document.getElementById('splash');
  if (splash) {
    splash.classList.add('hidden');
    setTimeout(() => splash.remove(), 500);
  }
  state.isLoading = false;
}

function setSplashStatus(text) {
  const statusEl = document.getElementById('splash-status');
  if (statusEl) statusEl.textContent = text;
}

function startSplashTicker() {
  stopSplashTicker();
  setSplashStatus(SPLASH_MESSAGES[0]);
  splashMessageInterval = setInterval(() => {
    splashMessageIndex = (splashMessageIndex + 1) % SPLASH_MESSAGES.length;
    setSplashStatus(SPLASH_MESSAGES[splashMessageIndex]);
  }, 1300);
}

function stopSplashTicker() {
  if (splashMessageInterval) {
    clearInterval(splashMessageInterval);
    splashMessageInterval = null;
  }
}

function initSplashInteractions() {
  const splash = document.getElementById('splash');
  const skipBtn = document.getElementById('splash-start-btn');
  if (!splash) return;

  if (skipBtn) {
    skipBtn.addEventListener('click', () => {
      setSplashStatus('Открываем карту...');
      hideSplash();
    });
  }

  splash.addEventListener('pointerdown', (event) => {
    const ripple = document.createElement('span');
    ripple.className = 'splash-ripple';
    ripple.style.left = \`\${event.clientX}px\`;
    ripple.style.top = \`\${event.clientY}px\`;
    splash.appendChild(ripple);
    setTimeout(() => ripple.remove(), 850);
  });

  startSplashTicker();
}

function showNotification(message, type = 'info') {
  const colors = {
    emergency: '#dc2626',
    new: '#10b981',
    info: '#3b82f6',
    error: '#ef4444'
  };
  
  const notification = document.createElement('div');
  notification.style.cssText = \`
    position:fixed;top:70px;left:50%;transform:translateX(-50%);
    padding:10px 18px;background:white;border-radius:20px;
    box-shadow:0 4px 20px rgba(0,0,0,0.15);font-size:13px;font-weight:500;
    color:#0f172a;z-index:9999;border-left:4px solid \${colors[type] || colors.info};
    animation:slideDown 0.3s ease;max-width:90%;text-align:center;
  \`;
  notification.textContent = message;
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.animation = 'slideUp 0.3s ease';
    setTimeout(() => notification.remove(), 300);
  }, type === 'emergency' ? 6000 : 4000);
}

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('ru-RU', {
    day: 'numeric', month: 'short', year: 'numeric'
  });
}

function getTimeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  const hours = Math.floor(mins / 60);
  const days = Math.floor(hours / 24);
  
  if (mins < 1) return 'сейчас';
  if (mins < 60) return \`\${mins} мин\`;
  if (hours < 24) return \`\${hours} ч\`;
  if (days < 7) return \`\${days} дн\`;
  return formatDate(dateStr);
}

// Animation keyframes
const style = document.createElement('style');
style.textContent = \`
  @keyframes slideDown { from{transform:translateX(-50%) translateY(-20px);opacity:0} to{transform:translateX(-50%) translateY(0);opacity:1} }
  @keyframes slideUp { from{transform:translateX(-50%) translateY(0);opacity:1} to{transform:translateX(-50%) translateY(-20px);opacity:0} }
  @keyframes emergency-pulse { 0%,100%{box-shadow:0 0 0 0 rgba(220,38,38,0.4)} 50%{box-shadow:0 0 0 8px rgba(220,38,38,0)} }
  .custom-cluster{background:transparent!important;border:none!important;}
  .popup-card.emergency{border:2px solid #dc2626;background:rgba(254,226,226,0.9)!important;}
\`;
document.head.appendChild(style);

// ═══════════════════════════════════════════════════════════════════════════════
// ADD COMPLAINT
// ═══════════════════════════════════════════════════════════════════════════════

function initAddComplaintButton() {
  const btn = document.getElementById('add-complaint-btn');
  if (!btn) return;
  
  btn.addEventListener('click', () => {
    const center = state.map.getCenter();
    alert(\`Добавление жалобы:\n\${center.lat.toFixed(6)}, \${center.lng.toFixed(6)}\`);
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

async function init() {
  console.log('🚀 Init...');
  initSplashInteractions();
  initBottomSheet();
  
  const supabaseOk = await initSupabase();
  if (!supabaseOk) console.warn('⚠️ Demo mode');
  
  if (!initMap()) return;
  
  initFilters();
  initAddComplaintButton();
  
  await loadComplaints();
  subscribeToRealtime();
  
  setSplashStatus('Готово');
  setTimeout(hideSplash, 550);
  console.log('✅ Ready');
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

window.addEventListener('beforeunload', () => {
  if (state.realtimeSubscription) {
    state.supabase.removeChannel(state.realtimeSubscription);
  }
});


const MapPulse = {
  bpm: 72,
  targetBpm: 72,
  canvas: null,
  ctx: null,
  history: [],
  frameCount: 0,
  
  init() {
    this.canvas = document.getElementById('mapPulseCanvas');
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    this.history = new Array(50).fill(0);
    this.animate();
    setInterval(() => this.updatePulse(), 2000);
  },
  
  updatePulse() {
    if (!state.complaints) return;
    
    // Calculate pulse based on today's complaints and categories
    const today = new Date();
    today.setHours(0,0,0,0);
    
    let todaysCount = 0;
    let emergencyCount = 0;
    
    state.complaints.forEach(c => {
      const created = new Date(c.created_at);
      if (created >= today) {
        todaysCount++;
        if (c.category === 'ЧП') emergencyCount++;
      }
    });
    
    let newBpm = 60 + (todaysCount * 0.5) + (emergencyCount * 10);
    if (newBpm > 160) newBpm = 160;
    
    this.targetBpm = newBpm;
    
    let mood = 'Спокойно';
    let color = '#10b981';
    if (this.targetBpm > 120 || emergencyCount > 0) {
      mood = 'ЧП / Тревога';
      color = '#dc2626';
    } else if (this.targetBpm > 90) {
      mood = 'Активно';
      color = '#f59e0b';
    } else if (this.targetBpm > 75) {
      mood = 'Умеренно';
      color = '#0ea5e9';
    }
    
    const bpmEl = document.getElementById('pulse-bpm');
    const moodEl = document.getElementById('pulse-mood');
    
    if (bpmEl) bpmEl.textContent = Math.round(this.targetBpm);
    if (moodEl) {
      moodEl.textContent = mood;
      moodEl.style.color = color;
    }
  },
  
  animate() {
    if (!this.canvas || !this.ctx) return;
    this.frameCount++;
    
    this.bpm += (this.targetBpm - this.bpm) * 0.05;
    
    const time = Date.now();
    const beatInterval = 60000 / this.bpm;
    const phase = (time % beatInterval) / beatInterval;
    
    let y = 0;
    if (phase < 0.1) y = Math.sin(phase * Math.PI * 10) * 15;
    else if (phase < 0.2) y = -Math.sin((phase - 0.1) * Math.PI * 10) * 8;
    else if (phase > 0.8 && phase < 0.9) y = Math.sin((phase - 0.8) * Math.PI * 10) * 5;
    
    // Add noise
    y += (Math.random() - 0.5) * 2;
    
    this.history.push(y);
    this.history.shift();
    
    const width = this.canvas.width;
    const height = this.canvas.height;
    
    this.ctx.clearRect(0, 0, width, height);
    this.ctx.beginPath();
    
    let color = '#10b981';
    if (this.bpm > 120) color = '#dc2626';
    else if (this.bpm > 90) color = '#f59e0b';
    
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 2;
    
    for (let i = 0; i < this.history.length; i++) {
      const x = (i / (this.history.length - 1)) * width;
      const val = height / 2 - this.history[i];
      if (i === 0) this.ctx.moveTo(x, val);
      else this.ctx.lineTo(x, val);
    }
    this.ctx.stroke();
    
    requestAnimationFrame(() => this.animate());
  }
};

</script>
</body>
</html>
`, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "X-Content-Type-Options": "nosniff",
      "Cache-Control": "public, max-age=0, must-revalidate"
    },
    status: 200
  });
});
