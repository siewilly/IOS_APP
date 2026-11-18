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
      if (w <= 0 || h <= 0) return;
      app.renderer.resize(w, h);

      // Reset model anchor to horizontal center and head top (0.5, 0)
      if (live2dModel.anchor && typeof live2dModel.anchor.set === 'function') {
        live2dModel.anchor.set(0.5, 0);
      }

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
    window.addEventListener('orientationchange', layoutModel);
    setTimeout(layoutModel, 100);
    setTimeout(layoutModel, 500);
    setTimeout(layoutModel, 1200);

    // =========================================================================
    // 4. v2.6.0 即時觸控粒子渲染與親密等級權限引擎 (Intimacy Biometric Engine)
    // =========================================================================
    let currentIntimacyScore = 271; // 預設同伴資料庫好感度（知心守護 271 分）

    function setIntimacyScore(score) {
      currentIntimacyScore = Math.max(0, Number(score) || 0);
      console.log('[Live2D WebEngine] Synchronized intimacyScore:', currentIntimacyScore);
    }

    // Canvas 飄逸粒子特效容器（心形、星光、微精靈冰晶）
    const fxContainer = new PIXI.Container();
    app.stage.addChild(fxContainer);
    const activeParticles = [];

    function spawnTouchParticle(clientX, clientY, icon) {
      try {
        const pText = new PIXI.Text(icon || '✨', {
          fontSize: Math.round(16 + Math.random() * 8),
        });
        pText.anchor.set(0.5);
        pText.x = clientX + (Math.random() - 0.5) * 36;
        pText.y = clientY + (Math.random() - 0.5) * 36;
        pText.alpha = 1.0;
        pText.scale.set(0.7 + Math.random() * 0.4);
        fxContainer.addChild(pText);

        activeParticles.push({
          display: pText,
          vx: (Math.random() - 0.5) * 1.6,
          vy: -2.0 - Math.random() * 2.2,
          vr: (Math.random() - 0.5) * 0.08,
          life: 1.0,
          decay: 0.028 + Math.random() * 0.015,
        });
      } catch (err) {
        // Safe fallback
      }
    }

    app.ticker.add((delta) => {
      const dt = delta || 1;
      for (let i = activeParticles.length - 1; i >= 0; i--) {
        const p = activeParticles[i];
        p.life -= p.decay * dt;
        p.display.x += p.vx * dt;
        p.display.y += p.vy * dt;
        p.display.rotation += p.vr * dt;
        p.display.alpha = Math.max(0, p.life);
        p.display.scale.x *= 0.99;
        p.display.scale.y *= 0.99;
        if (p.life <= 0) {
          fxContainer.removeChild(p.display);
          try { p.display.destroy(); } catch (e) {}
          activeParticles.splice(i, 1);
        }
      }
    });

    // 嚴格好感度階級權限對照表
    const TOUCH_PARTS = {
      head: {
        name: '撫摸銀髮 (頭部)',
        minScore: 0,
        minLevel: 1,
        levelName: '初識同伴',
        motion: 'TapHead',
        expression: 'exp_01_subtle_smile',
        activeLabel: '✨ 正在溫柔撫摸銀髮 (頭部)',
        toastUnlocked: '✋ 輕撫銀髮，愛蜜莉雅舒服地瞇起眼睛～',
        toastLocked: '🔒 需要好感度 Lv.1 解鎖',
        icons: ['🌸', '✨', '💕']
      },
      cheek: {
        name: '戳戳臉頰',
        minScore: 0,
        minLevel: 1,
        levelName: '初識同伴',
        motion: 'Shy',
        expression: 'exp_05_shy',
        activeLabel: '😳 正在戳戳臉頰',
        toastUnlocked: '😳 戳戳臉頰，愛蜜莉雅害羞地縮了下脖子！',
        toastLocked: '🔒 需要好感度 Lv.1 解鎖',
        icons: ['😳', '💖', '✨']
      },
      shoulder: {
        name: '輕拉衣角 / 輕拍肩',
        minScore: 80,
        minLevel: 2,
        levelName: '信任夥伴',
        motion: 'TapBody',
        expression: 'exp_04_smug',
        activeLabel: '🌿 正在輕拉衣角',
        toastUnlocked: '🌿 輕拉衣角，愛蜜莉雅轉頭溫柔地注視著你～',
        toastLocked: '🔒 需要好感度 Lv.2（信任夥伴 80分）解鎖！現在還稍微有點生疏呢...',
        icons: ['🌿', '✨', '🌸']
      },
      hand: {
        name: '十指緊扣牽手',
        minScore: 450,
        minLevel: 4,
        levelName: '專屬戀人 (EMT)',
        motion: 'Appeal',
        expression: 'exp_21_adoration_sparkle',
        activeLabel: '🤝 正在牽牽小手',
        toastUnlocked: '🤝 十指緊扣，感受掌心傳遞的溫暖，感到無比安心...',
        toastLocked: '🔒 需要好感度 Lv.4（專屬戀人 450分）解鎖！「那個……現在牽手還太害羞了啦……」',
        icons: ['🤝', '💖', '💕']
      },
      crystal: {
        name: '觸碰契約水晶',
        minScore: 800,
        minLevel: 5,
        levelName: '精靈的契約者',
        motion: 'Appeal',
        expression: 'exp_21_adoration_sparkle',
        activeLabel: '💎 正在輕觸契約水晶',
        toastUnlocked: '💎 輕觸契約水晶，微精靈微光與心跳柔和共鳴...',
        toastLocked: '🔒 需要好感度 Lv.5（精靈的契約者 800分）解鎖！「契約水晶是帕克的居所，要等到真正心意相通才能觸碰喔……」',
        icons: ['💎', '✨', '❄️']
      },
      chin: {
        name: '摸摸下巴逗笑',
        minScore: 2000,
        minLevel: 7,
        levelName: '銀白之戀 · 冰結羈絆',
        motion: 'Happy',
        expression: 'exp_02_happy_big',
        activeLabel: '❄️ 正在摸摸下巴',
        toastUnlocked: '❄️ 摸摸下巴，愛蜜莉雅被逗得開懷歡笑～',
        toastLocked: '🔒 需要好感度 Lv.7（冰結羈絆 2000分）解鎖！「呼哇……那樣摸下巴像在逗小貓一樣，太令人害羞了啦！」',
        icons: ['❄️', '✨', '😄']
      }
    };

    function detectTouchPart(clientX, clientY) {
      if (!live2dModel) return 'head';
      const scale = live2dModel.scale.x;
      const relX = clientX - live2dModel.x;
      const relY = clientY - live2dModel.y;

      const localX = (relX / scale) + 1500;
      const localY = relY / scale;

      if (localY >= 350 && localY < 950 && Math.abs(localX - 1500) <= 480) {
        return 'head';
      } else if (localY >= 950 && localY < 1180 && Math.abs(localX - 1500) >= 120 && Math.abs(localX - 1500) <= 420) {
        return 'cheek';
      } else if (localY >= 1150 && localY < 1320 && Math.abs(localX - 1500) < 130) {
        return 'chin';
      } else if (localY >= 1320 && localY < 1550 && Math.abs(localX - 1500) <= 160) {
        return 'crystal';
      } else if (localY >= 1320 && localY < 1900 && Math.abs(localX - 1500) > 160 && Math.abs(localX - 1500) <= 500) {
        return 'shoulder';
      } else if (localY >= 1900 && Math.abs(localX - 1500) <= 550) {
        return 'hand';
      }
      return 'head';
    }

    let isPointerActive = false;
    let activeTouchArea = null;

    canvas.addEventListener('pointerdown', (e) => {
      isPointerActive = true;
      wakeToActiveFPS(3.5);
      const target = detectTouchPart(e.clientX, e.clientY);
      activeTouchArea = target;
      const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
      const isUnlocked = currentIntimacyScore >= def.minScore;

      // 即刻噴發專屬互動粒子
      const pIcons = isUnlocked ? def.icons : ['🔒', '❓'];
      for (let i = 0; i < 3; i++) {
        spawnTouchParticle(e.clientX, e.clientY, pIcons[i % pIcons.length]);
      }

      // 即刻通知 Swift 顯示頂部即時觸控狀態指示
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTouchDown) {
        window.webkit.messageHandlers.live2dTouchDown.postMessage({
          area: target,
          name: def.name,
          activeLabel: isUnlocked ? def.activeLabel : ('🔒 ' + def.name + ' (需 Lv.' + def.minLevel + ' ' + def.levelName + ' ' + def.minScore + '分)'),
          isLocked: !isUnlocked,
          minScore: def.minScore,
          levelName: def.levelName
        });
      }
    });

    canvas.addEventListener('pointermove', (e) => {
      if (!isPointerActive) return;
      const target = detectTouchPart(e.clientX, e.clientY);
      if (Math.random() < 0.3) {
        const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
        const isUnlocked = currentIntimacyScore >= def.minScore;
        spawnTouchParticle(e.clientX, e.clientY, isUnlocked ? '✨' : '🔒');
      }

      if (target !== activeTouchArea) {
        activeTouchArea = target;
        const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
        const isUnlocked = currentIntimacyScore >= def.minScore;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTouchMove) {
          window.webkit.messageHandlers.live2dTouchMove.postMessage({
            area: target,
            name: def.name,
            activeLabel: isUnlocked ? def.activeLabel : ('🔒 ' + def.name + ' (需 Lv.' + def.minLevel + ' ' + def.levelName + ' ' + def.minScore + '分)'),
            isLocked: !isUnlocked
          });
        }
      }
    });

    canvas.addEventListener('pointerup', (e) => {
      if (!isPointerActive) return;
      isPointerActive = false;
      wakeToActiveFPS(3.5);
      const target = activeTouchArea || detectTouchPart(e.clientX, e.clientY);
      const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
      const isUnlocked = currentIntimacyScore >= def.minScore;

      if (isUnlocked) {
        triggerMotion(def.motion);
        setExpression(def.expression);
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
          window.webkit.messageHandlers.live2dTap.postMessage({
            area: target,
            text: def.toastUnlocked,
            isLocked: false
          });
        }
      } else {
        // 嚴格權限鎖定：害羞縮身偏頭拒絕，絕不觸發親密動作
        triggerMotion('Shy');
        setExpression('exp_05_shy');
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
          window.webkit.messageHandlers.live2dTap.postMessage({
            area: target,
            text: def.toastLocked,
            isLocked: true
          });
        }
      }
    });

    canvas.addEventListener('pointercancel', () => {
      isPointerActive = false;
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

  let currentOutfit = 'classic';

  async function switchOutfit(outfitId) {
    if (outfitId === currentOutfit && live2dModel) return;
    const modelPath = outfitId === 'swimsuit' ? 'model_ss/Character.model3.json' : 'model/Character.model3.json';

    try {
      console.log('[Live2D WebEngine] Switching outfit to:', outfitId, modelPath);
      const newModel = await PIXI.live2d.Live2DModel.from(modelPath, { autoInteract: false });

      if (live2dModel) {
        app.stage.removeChild(live2dModel);
        try { live2dModel.destroy({ children: true }); } catch (e) {}
      }

      live2dModel = newModel;
      app.stage.addChild(live2dModel);
      window.__model = live2dModel;
      currentOutfit = outfitId;

      layoutModel();
      wakeToActiveFPS(3.0);
      console.log('[Live2D WebEngine] Outfit switched successfully to:', outfitId);
    } catch (err) {
      console.error('[Live2D WebEngine] Failed to switch outfit:', err);
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
    switchOutfit,
    setIntimacyScore,
    layoutModel,
    getCurrentOutfit: () => currentOutfit,
    isReady: () => !!live2dModel,
    getActiveFPS: () => app.ticker.maxFPS,
  };
})();
