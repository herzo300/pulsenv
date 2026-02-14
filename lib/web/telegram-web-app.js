// web/telegram-web-app.js
// Telegram Web App Integration

(function() {
  'use strict';
  
  // Проверяем, открыто ли в Telegram
  if (!window.Telegram || !window.Telegram.WebApp) {
    console.log('Не в Telegram WebApp');
    return;
  }
  
  const tg = window.Telegram.WebApp;
  
  // Инициализация
  tg.ready();
  tg.expand();
  
  // Настройка внешнего вида
  tg.setHeaderColor('#6366F1');
  tg.setBackgroundColor('#0F172A');
  
  // Получение данных пользователя
  const initData = tg.initDataUnsafe;
  const user = initData?.user;
  
  if (user) {
    console.log('Telegram User:', user);
    
    // Сохраняем в localStorage для Flutter
    localStorage.setItem('telegram_user', JSON.stringify({
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      username: user.username,
      photo_url: user.photo_url,
    }));
    
    // Устанавливаем глобальную переменную
    window.TELEGRAM_USER = user;
  }
  
  // Main Button для быстрого создания жалобы
  tg.MainButton.setParams({
    text: '📝 Создать жалобу',
    color: '#6366F1',
    text_color: '#FFFFFF',
    is_visible: true,
  });
  
  tg.MainButton.onClick(function() {
    // Отправляем сообщение в Flutter
    if (window.flutterApp) {
      window.flutterApp.postMessage(JSON.stringify({
        action: 'create_complaint',
        source: 'main_button'
      }));
    }
    
    // Или через событие
    window.dispatchEvent(new CustomEvent('telegram-main-button-clicked'));
  });
  
  // Back Button
  tg.BackButton.onClick(function() {
    window.dispatchEvent(new CustomEvent('telegram-back-button-clicked'));
  });
  
  // Обработка событий viewport
  tg.onEvent('viewportChanged', function() {
    console.log('Viewport changed:', tg.viewportHeight);
    window.dispatchEvent(new CustomEvent('telegram-viewport-changed', {
      detail: { height: tg.viewportHeight }
    }));
  });
  
  // Глобальная функция для Flutter
  window.sendToTelegram = function(data) {
    tg.sendData(JSON.stringify(data));
  };
  
  window.showTelegramAlert = function(message) {
    tg.showAlert(message);
  };
  
  window.showTelegramConfirm = function(message, callback) {
    tg.showConfirm(message).then(function(result) {
      if (callback) callback(result);
    });
  };
  
  window.closeTelegramApp = function() {
    tg.close();
  };
  
  console.log('✅ Telegram WebApp инициализирован');
})();
