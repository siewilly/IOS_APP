/**
 * Live2D Anti-Overheating WebEngine Renderer
 * Designed for iOS WKWebView low-power operation
 * Synchronized with v2.3.0 Biometric & Precise Hit Testing Engine
 */
(async function initLive2DRenderer() {
  const canvas = document.getElementById('canvas');

  // 1. Configure high-precision Retina WebGL settings
  if (window.PIXI && PIXI.settings) {
    PIXI.settings.SCALE_MODE = PIXI.SCALE_MODES.LINEAR;
    PIXI.settings.MIPMAP_TEXTURES = PIXI.MIPMAP_MODES.ON;
    PIXI.settings.ROUND_PIXELS = false;
    PIXI.settings.PRECISION_FRAGMENT = 'highp';
  }

  // Device pixel ratio: natively match iPhone 14/15 3x OLED screen for pristine crispness
  const dpr = Math.min(Math.max(window.devicePixelRatio || 2, 2), 3);

  const app = new PIXI.Application({
    view: canvas,
    autoStart: true,
    transparent: true,
    backgroundAlpha: 0,
    resolution: dpr, // Ultra-sharp Retina native resolution
    autoDensity: true,
    antialias: true, // Smooth anti-aliased geometry and lines
    powerPreference: 'high-performance',
    width: window.innerWidth || 390,
    height: window.innerHeight || 844,
  });

  // 2. Framerate Management (60 FPS fluid mode vs 30/15 FPS battery saver)
  let is60FPSMode = true; // Default to 60 FPS full fluidity
  let IDLE_FPS = 60;
  let ACTIVE_FPS = 60;
  app.ticker.maxFPS = 60;

  let boostTimer = null;
  let currentMouthOpen = 0;
  let isSpeaking = false;
  let live2dModel = null;

  function applyFPSMode(enabled) {
    is60FPSMode = !!enabled;
    if (is60FPSMode) {
      IDLE_FPS = 60;
      ACTIVE_FPS = 60;
      app.ticker.maxFPS = 60;
    } else {
      IDLE_FPS = 15;
      ACTIVE_FPS = 30;
      app.ticker.maxFPS = IDLE_FPS;
    }
    console.log('[Live2D WebEngine] FPS mode updated. is60FPS:', is60FPSMode, 'targetFPS:', app.ticker.maxFPS);
  }

  function wakeToActiveFPS(durationSeconds = 2.5) {
    if (is60FPSMode) {
      app.ticker.maxFPS = 60;
      return;
    }
    app.ticker.maxFPS = ACTIVE_FPS;
    if (boostTimer) {
      clearTimeout(boostTimer);
    }
    boostTimer = setTimeout(() => {
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
    window.__model = live2dModel;
    window.__app = app;

    function layoutModel() {
      if (!live2dModel) return;
      const w = window.innerWidth || 390;
      const h = window.innerHeight || 844;
      app.renderer.resize(w, h);

      // Reset model anchor to horizontal center and head top (0.5, 0)
      live2dModel.anchor.set(0.5, 0);

      // Option A: Balanced framing (head to thighs - typical VTuber companion framing)
      const origH = (live2dModel.internalModel && live2dModel.internalModel.originalHeight) || 4500;
      const scale = (h * 1.05) / origH;
      live2dModel.scale.set(scale);

      // Horizontally centered, top positioned at 7% screen height
      live2dModel.x = w / 2;
      live2dModel.y = h * 0.07;
    }

    layoutModel();
    window.addEventListener('resize', layoutModel);

    // 4. v2.3.0 精準觸控感應（摸頭、戳臉、摸下巴、契約水晶、拉衣角、牽手）
    // 採用模型原生本地座標系 (0~3000, 0~4500)，不受任何解析度或縮放影響
    canvas.addEventListener('pointerup', (e) => {
      wakeToActiveFPS(3.5);
      if (!live2dModel) return;

      const scale = live2dModel.scale.x;
      const relX = e.clientX - live2dModel.x;
      const relY = e.clientY - live2dModel.y;

      // 轉換為模型本地座標 (寬度 0~3000，中心 1500；高度 0~4500)
      const localX = (relX / scale) + 1500;
      const localY = relY / scale;

      let part = 'body';
      let toast = '🌸 愛蜜莉雅溫柔地注視著你...';

      if (localY >= 400 && localY < 950 && Math.abs(localX - 1500) <= 450) {
        // 1. 摸摸銀髮 / 摸頭
        part = 'head';
        toast = '✋ 輕撫銀髮，愛蜜莉雅舒服地瞇起眼睛～';
        triggerMotion('TapHead');
        setExpression('exp_01_subtle_smile');
      } else if (localY >= 950 && localY < 1180 && Math.abs(localX - 1500) >= 120 && Math.abs(localX - 1500) <= 400) {
        // 2. 戳戳臉頰（縮頸害羞）
        part = 'cheek';
        toast = '😳 戳戳臉頰，愛蜜莉雅害羞地縮了下脖子！';
        triggerMotion('Shy');
        setExpression('exp_05_shy');
      } else if (localY >= 1150 && localY < 1320 && Math.abs(localX - 1500) < 120) {
        // 3. 摸摸下巴（逗笑開懷）
        part = 'chin';
        toast = '❄️ 摸摸下巴，愛蜜莉雅開心地笑了～';
        triggerMotion('Happy');
        setExpression('exp_02_happy_big');
      } else if (localY >= 1320 && localY < 1550 && Math.abs(localX - 1500) <= 150) {
        // 4. 契約水晶（共鳴依偎）
        part = 'crystal';
        toast = '💎 輕觸契約水晶，微光與心跳柔和共鳴...';
        triggerMotion('Appeal');
        setExpression('exp_21_adoration_sparkle');
      } else if (localY >= 1320 && localY < 1900 && Math.abs(localX - 1500) > 150) {
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
    setFPSMode: applyFPSMode,
    isReady: () => !!live2dModel,
    getActiveFPS: () => app.ticker.maxFPS,
  };
})();
