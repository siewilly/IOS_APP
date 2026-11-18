/**
 * Live2D Anti-Overheating WebEngine Renderer
 * Designed for iOS WKWebView low-power operation
 * Synchronized with v2.3.0 Biometric & Precise Hit Testing Engine
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

  function wakeToActiveFPS(durationSeconds = 2.5) {
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

    // 4. v2.3.0 精準觸控感應（摸頭、戳臉、摸下巴、契約水晶、拉衣角、牽手）
    canvas.addEventListener('pointerup', (e) => {
      wakeToActiveFPS(3.5);
      const w = window.innerWidth || 390;
      const h = window.innerHeight || 844;

      const modelW = (live2dModel.internalModel.width || 1200) * live2dModel.scale.x;
      const modelH = (live2dModel.internalModel.height || 1200) * live2dModel.scale.y;
      const modelCenterX = live2dModel.x + modelW / 2;
      const modelTopY = live2dModel.y;

      // 正規化座標：normX (-1.0 到 +1.0，0 為臉部中心)，normY (0.0 頂部到 1.0 底部)
      const normX = (e.clientX - modelCenterX) / (modelW / 2);
      const normY = (e.clientY - modelTopY) / modelH;

      let part = 'body';
      let toast = '🌸 愛蜜莉雅溫柔地注視著你...';

      if (normY < 0.36 && Math.abs(normX) <= 0.70) {
        // 1. 摸摸銀髮 / 摸頭
        part = 'head';
        toast = '✋ 輕撫銀髮，愛蜜莉雅舒服地瞇起眼睛～';
        triggerMotion('TapHead');
        setExpression('exp_01_subtle_smile');
      } else if (normY >= 0.36 && normY < 0.48 && Math.abs(normX) >= 0.16 && Math.abs(normX) <= 0.65) {
        // 2. 戳戳臉頰（縮頸害羞）
        part = 'cheek';
        toast = '😳 戳戳臉頰，愛蜜莉雅害羞地縮了下脖子！';
        triggerMotion('Shy');
        setExpression('exp_05_shy');
      } else if (normY >= 0.44 && normY < 0.52 && Math.abs(normX) < 0.18) {
        // 3. 摸摸下巴（逗笑開懷）
        part = 'chin';
        toast = '❄️ 摸摸下巴，愛蜜莉雅開心地笑了～';
        triggerMotion('Happy');
        setExpression('exp_02_happy_big');
      } else if (normY >= 0.52 && normY < 0.64 && Math.abs(normX) <= 0.25) {
        // 4. 契約水晶（共鳴依偎）
        part = 'crystal';
        toast = '💎 輕觸契約水晶，微光與心跳柔和共鳴...';
        triggerMotion('Appeal');
        setExpression('exp_21_adoration_sparkle');
      } else if (normY >= 0.50 && normY < 0.66 && Math.abs(normX) > 0.25) {
        // 5. 輕拉衣角 / 輕拍肩
        part = 'shoulder';
        toast = '🌿 輕拉衣角，愛蜜莉雅轉頭望向你～';
        triggerMotion('TapBody');
        setExpression('exp_04_smug');
      } else {
        // 6. 牽牽手 / 身體互動
        part = 'hand';
        toast = '🤝 牽牽小手，感到無比安心...';
        triggerMotion('TapBody');
        setExpression('exp_01_subtle_smile');
      }

      // 通知 Swift 原生端顯示互動回饋
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
        window.webkit.messageHandlers.live2dTap.postMessage({ area: part, text: toast });
      }
    });

    // 5. Lip-sync synchronization hook
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
    console.log('[Live2D WebEngine] v2.3.0 Model successfully loaded at 12 FPS idle profile.');
  } catch (error) {
    console.error('[Live2D WebEngine] Failed to initialize model:', error);
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dError) {
      window.webkit.messageHandlers.live2dError.postMessage({ error: String(error) });
    }
  }

  // 6. Swift Bridge Implementation
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
