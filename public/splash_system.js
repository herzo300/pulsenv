(function initSplashModule() {
  const STORAGE_KEY = 'pulse-city-splash-sequence';
  const DEFAULT_VOLUME = 0.18;

  class SplashController {
    constructor(options = {}) {
      this.root = document.getElementById(options.rootId || 'splash');
      this.messages = options.messages || [];
      this.variants = options.variants || [];
      this.progress = Number(options.initialProgress || 10);
      this.audioEnabled = options.audioEnabled !== false;
      this.onAudioChange = options.onAudioChange || (() => {});
      this.onProgress = options.onProgress || (() => {});
      this.onHidden = options.onHidden || (() => {});
      this.messageIndex = 0;
      this.messageInterval = null;
      this.pointerFrame = null;
      this.audioFadeInterval = null;
      this.audioStarted = false;
      this.autoplayBlocked = false;
      this.currentVariant = null;
    }

    init() {
      if (!this.root) {
        return this;
      }

      this.applyNextVariant(true);
      this.attachListeners();
      this.setProgress(this.progress);
      this.updateAudioLabel();
      this.tryStartAudio();
      this.startTicker();
      this.resetParallax();
      return this;
    }

    attachListeners() {
      const skipBtn = document.getElementById('splash-start-btn');
      const audioBtn = document.getElementById('splash-audio-btn');

      if (skipBtn) {
        skipBtn.addEventListener('click', () => {
          this.setStatus('Открываем карту...', 100);
          this.hide();
        });
      }

      if (audioBtn) {
        audioBtn.addEventListener('click', (event) => {
          event.stopPropagation();
          this.toggleAudio();
        });
      }

      this.root.addEventListener('pointerdown', (event) => {
        if (this.audioEnabled && !this.audioStarted) {
          this.tryStartAudio();
        }
        this.emitRipple(event);
      });

      this.root.addEventListener('pointermove', (event) => {
        this.updateParallax(event.clientX, event.clientY);
      });

      this.root.addEventListener('pointerleave', () => {
        this.resetParallax();
      });
    }

    claimNextVariant() {
      if (!this.variants.length) {
        return null;
      }

      let index = 0;
      try {
        const storedValue = Number(window.localStorage.getItem(STORAGE_KEY));
        if (Number.isInteger(storedValue) && storedValue >= 0) {
          index = (storedValue + 1) % this.variants.length;
        }
        window.localStorage.setItem(STORAGE_KEY, String(index));
      } catch (_error) {
        index = 0;
      }

      return this.variants[index];
    }

    applyNextVariant(withTransition = true) {
      if (!this.root) {
        return;
      }

      const variant = this.claimNextVariant();
      if (!variant) {
        return;
      }

      this.currentVariant = variant;
      this.root.dataset.splashTheme = variant.key;

      if (withTransition) {
        this.root.classList.remove('splash-theme-transition');
        // Force reflow so the blur transition retriggers on each new startup.
        void this.root.offsetWidth;
        this.root.classList.add('splash-theme-transition');
        window.setTimeout(() => {
          this.root?.classList.remove('splash-theme-transition');
        }, 950);
      }

      this.writeText('splash-theme-name', variant.themeName);
      this.writeText('splash-kicker', variant.kicker);
      this.writeText('splash-title-main', variant.title);
      this.writeText('splash-subtitle-main', variant.subtitle);
      this.writeText('splash-meta-mode', variant.mode);
      this.writeText('splash-emblem-icon', variant.icon);

      const audioEl = this.getAudioElement();
      if (audioEl) {
        audioEl.src = variant.audio;
        audioEl.volume = DEFAULT_VOLUME;
        audioEl.load();
      }
    }

    setProgress(progress) {
      this.progress = Math.max(0, Math.min(100, progress));
      const progressEl = document.getElementById('splash-progress-fill');
      if (progressEl) {
        progressEl.style.width = `${this.progress}%`;
      }
      this.onProgress(this.progress);
    }

    setStatus(text, progress = null) {
      this.writeText('splash-status', text);
      if (typeof progress === 'number') {
        this.setProgress(progress);
      } else {
        this.setProgress(this.progress + 6);
      }
    }

    startTicker() {
      this.stopTicker();
      if (!this.messages.length) {
        return;
      }

      this.messageIndex = 0;
      this.setStatus(this.messages[this.messageIndex]);
      this.messageInterval = window.setInterval(() => {
        this.messageIndex = (this.messageIndex + 1) % this.messages.length;
        this.setStatus(this.messages[this.messageIndex]);
      }, 1300);
    }

    stopTicker() {
      if (this.messageInterval) {
        window.clearInterval(this.messageInterval);
        this.messageInterval = null;
      }
    }

    getAudioElement() {
      return document.getElementById('splash-audio');
    }

    updateAudioLabel() {
      const labelEl = document.getElementById('splash-audio-label');
      if (!labelEl) {
        return;
      }

      if (!this.audioEnabled) {
        labelEl.textContent = 'MP3 OFF';
      } else if (this.autoplayBlocked && !this.audioStarted) {
        labelEl.textContent = 'TAP FOR SOUND';
      } else {
        labelEl.textContent = 'MP3 ON';
      }
    }

    async tryStartAudio() {
      const audioEl = this.getAudioElement();
      if (!audioEl || !this.audioEnabled || this.audioStarted) {
        return;
      }

      try {
        await audioEl.play();
        this.audioStarted = true;
        this.autoplayBlocked = false;
      } catch (_error) {
        this.autoplayBlocked = true;
      }

      this.updateAudioLabel();
    }

    stopAudio() {
      const audioEl = this.getAudioElement();
      if (!audioEl) {
        return;
      }

      if (this.audioFadeInterval) {
        window.clearInterval(this.audioFadeInterval);
      }

      this.audioFadeInterval = window.setInterval(() => {
        if (audioEl.volume <= 0.03) {
          window.clearInterval(this.audioFadeInterval);
          this.audioFadeInterval = null;
          audioEl.pause();
          audioEl.currentTime = 0;
          audioEl.volume = DEFAULT_VOLUME;
          this.audioStarted = false;
          return;
        }
        audioEl.volume = Math.max(0, audioEl.volume - 0.03);
      }, 40);
    }

    toggleAudio(forceValue) {
      this.audioEnabled =
        typeof forceValue === 'boolean' ? forceValue : !this.audioEnabled;
      this.onAudioChange(this.audioEnabled);

      const audioEl = this.getAudioElement();
      if (audioEl) {
        if (this.audioEnabled) {
          audioEl.volume = DEFAULT_VOLUME;
          this.tryStartAudio();
        } else {
          audioEl.pause();
          this.audioStarted = false;
        }
      }

      this.updateAudioLabel();
    }

    emitRipple(event) {
      if (!this.root) {
        return;
      }

      const ripple = document.createElement('span');
      ripple.className = 'splash-ripple';
      ripple.style.left = `${event.clientX}px`;
      ripple.style.top = `${event.clientY}px`;
      this.root.appendChild(ripple);
      window.setTimeout(() => ripple.remove(), 850);
    }

    updateParallax(clientX, clientY) {
      if (!this.root) {
        return;
      }

      const bounds = this.root.getBoundingClientRect();
      const centerX = bounds.left + bounds.width / 2;
      const centerY = bounds.top + bounds.height / 2;
      const offsetX = (clientX - centerX) / (bounds.width / 2);
      const offsetY = (clientY - centerY) / (bounds.height / 2);
      const x = Math.max(-1, Math.min(1, offsetX));
      const y = Math.max(-1, Math.min(1, offsetY));

      if (this.pointerFrame) {
        window.cancelAnimationFrame(this.pointerFrame);
      }

      this.pointerFrame = window.requestAnimationFrame(() => {
        if (!this.root) {
          return;
        }
        this.root.style.setProperty('--splash-parallax-x', x.toFixed(3));
        this.root.style.setProperty('--splash-parallax-y', y.toFixed(3));
        this.root.style.setProperty(
          '--splash-pointer-glow',
          `${Math.abs(x) + Math.abs(y)}`
        );
      });
    }

    resetParallax() {
      if (!this.root) {
        return;
      }

      this.root.style.setProperty('--splash-parallax-x', '0');
      this.root.style.setProperty('--splash-parallax-y', '0');
      this.root.style.setProperty('--splash-pointer-glow', '0');
    }

    hide() {
      this.stopTicker();
      this.setProgress(100);
      this.stopAudio();
      this.resetParallax();
      if (this.root) {
        this.root.classList.add('hidden');
        window.setTimeout(() => {
          this.root?.remove();
        }, 500);
      }
      this.onHidden();
    }

    writeText(id, value) {
      const el = document.getElementById(id);
      if (el) {
        el.textContent = value;
      }
    }
  }

  window.SplashSystem = {
    create(options) {
      return new SplashController(options);
    },
  };
})();
