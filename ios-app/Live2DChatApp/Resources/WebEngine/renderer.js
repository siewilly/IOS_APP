/**
 * Live2D Anti-Overheating WebEngine Renderer
 * Designed for iOS WKWebView low-power operation
 */
(async function initLive2DRenderer() {
  const canvas = document.getElementById('canvas');

  // 1. Mandatory low-power and resolution constraints
  const app = new PIXI.Application({
    view: canvas,
    autoStart: true,
    transparent: true,
    backgroundAlpha: 0,
    resolution: 1, // STRICTLY 1: Never use window.devicePixelRatio to prevent 9x pixel overhead
    autoDensity: false,
    antialias: false,
    powerPreference: 'low-power',
    width: window.innerWidth || 390,
    height: window.innerHeight || 844,
  });

  // 2. Dynamic frame rate throttling: 12 FPS idle vs 30 FPS active
  const IDLE_FPS = 12;
  const ACTIVE_FPS = 30;
  app.ticker.maxFPS = IDLE_FPS;

  let boostTimer = null;
  let currentMouthOpen = 0;
  let isSpeaking = false;
  let live2dModel = null;

  function wakeToActiveFPS(durationSeconds = 2) {
    app.ticker.maxFPS = ACTIVE_FPS;
    if (boostTimer) {
      clearTimeout(boostTimer);
    }
    boostTimer = setTimeout(() => {
      // Revert to 12 FPS only if speaking has ceased
      if (!isSpeaking && currentMouthOpen <= 0.01) {
        app.ticker.maxFPS = IDLE_FPS;
      }
    }, durationSeconds * 1000);
  }

  // 3. Model Loading
  try {
    // Model configuration is loaded locally from model/Character.model3.json
    live2dModel = await PIXI.live2d.Live2DModel.from('model/Character.model3.json', {
      autoInteract: false,
    });

    app.stage.addChild(live2dModel);

    function layoutModel() {
      if (!live2dModel) return;
      const w = window.innerWidth || 390;
      const h = window.innerHeight || 844;
      app.renderer.resize(w, h);

      const modelW = live2dModel.internalModel.width || 1200;
      const modelH = live2dModel.internalModel.height || 1200;

      // Scale to fit screen height nicely while keeping upper body/face centered
      const scale = (h * 0.88) / modelH;
      live2dModel.scale.set(scale);

      // Center horizontally
      live2dModel.x = (w - modelW * scale) / 2;
      // Position slightly from top
      live2dModel.y = h * 0.10;
    }

    layoutModel();
    window.addEventListener('resize', layoutModel);

    // Interactive tap response (摸頭與戳臉精準判定)
    canvas.addEventListener('pointerup', (e) => {
      wakeToActiveFPS(3);
      const w = window.innerWidth || 390;
      const h = window.innerHeight || 844;
      const ratioX = e.clientX / w;
      const ratioY = e.clientY / h;

      if (ratioY < 0.35) {
        // 摸頭 (Head Patting / Stroking)
        triggerMotion('TapHead');
        setExpression('exp_01_subtle_smile');
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
          window.webkit.messageHandlers.live2dTap.postMessage({ area: 'head' });
        }
      } else if (ratioY >= 0.35 && ratioY < 0.48 && ratioX >= 0.25 && ratioX <= 0.75) {
        // 戳臉頰 (Cheek Poke / Blushing)
        triggerMotion('Shy');
        setExpression('exp_05_shy');
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
          window.webkit.messageHandlers.live2dTap.postMessage({ area: 'cheek' });
        }
      } else {
        // 身體 (Body Tap)
        triggerMotion('TapBody');
        setExpression('exp_04_smug');
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
          window.webkit.messageHandlers.live2dTap.postMessage({ area: 'body' });
        }
      }
    });

    // 4. Lip-sync synchronization hook
    // Override mouth open parameter on every rendered tick
    app.ticker.add(() => {
      if (!live2dModel || !live2dModel.internalModel || !live2dModel.internalModel.coreModel) return;
      const core = live2dModel.internalModel.coreModel;
      if (typeof core.setParameterValueById === 'function') {
        core.setParameterValueById('ParamMouthOpenY', currentMouthOpen);
        core.setParameterValueById('PARAM_MOUTH_OPEN_Y', currentMouthOpen);
      }
    });

    // Notify Swift native side that engine is ready
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dReady) {
      window.webkit.messageHandlers.live2dReady.postMessage({ status: 'ready' });
    }
    console.log('[Live2D WebEngine] Model successfully loaded at 12 FPS idle profile.');
  } catch (error) {
    console.error('[Live2D WebEngine] Failed to initialize model:', error);
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dError) {
      window.webkit.messageHandlers.live2dError.postMessage({ error: String(error) });
    }
  }

  // 5. Swift Bridge Implementation
  function setMouthOpen(value) {
    const val = Math.max(0, Math.min(1, Number(value) || 0));
    currentMouthOpen = val;

    if (val > 0.02) {
      isSpeaking = true;
      wakeToActiveFPS(2);
    } else if (isSpeaking && val <= 0.01) {
      isSpeaking = false;
      wakeToActiveFPS(2); // Keep 30 FPS for 2 seconds after speech stops, then down to 12
    }
  }

  function triggerMotion(group, index) {
    wakeToActiveFPS(3.5);
    if (!live2dModel) return;
    try {
      if (group) {
        if (typeof index === 'number' && index >= 0) {
          live2dModel.motion(group, index);
        } else {
          live2dModel.motion(group);
        }
      }
    } catch (e) {
      console.warn('[Live2D WebEngine] triggerMotion warning:', e);
    }
  }

  function setExpression(expId) {
    wakeToActiveFPS(2.5);
    if (!live2dModel) return;
    try {
      if (expId !== undefined && expId !== null && expId !== '') {
        live2dModel.expression(expId);
      }
    } catch (e) {
      console.warn('[Live2D WebEngine] setExpression warning:', e);
    }
  }

  function setPaused(isPaused) {
    if (isPaused) {
      if (app && app.ticker && app.ticker.started) {
        app.ticker.stop();
        console.log('[Live2D WebEngine] Ticker stopped (paused).');
      }
    } else {
      if (app && app.ticker && !app.ticker.started) {
        app.ticker.start();
        console.log('[Live2D WebEngine] Ticker resumed.');
      }
    }
  }

  // Expose to window.Live2DBridge
  window.Live2DBridge = {
    setMouthOpen,
    triggerMotion,
    setExpression,
    setPaused,
    isReady: () => !!live2dModel,
    getActiveFPS: () => app.ticker.maxFPS,
  };
})();
