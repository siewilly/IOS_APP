/**
 * Live2D Anti-Overheating WebEngine Renderer
 * Designed for iOS WKWebView 60 FPS / Battery-Saver Operation
 * Synchronized 1:1 with Desktop Pet Motion Director, IdleMacro Scheduler,
 * Speech Gesture Layer & Biometric Neuron Engine
 */
(async function initLive2DRenderer() {
  const canvas = document.getElementById('canvas');

  // 1. Configure high-precision Retina WebGL & Cubism settings
  if (window.PIXI && PIXI.settings) {
    PIXI.settings.SCALE_MODE = PIXI.SCALE_MODES.LINEAR;
    PIXI.settings.MIPMAP_TEXTURES = PIXI.MIPMAP_MODES.ON;
    PIXI.settings.ROUND_PIXELS = false;
    PIXI.settings.PRECISION_FRAGMENT = 'highp';
  }

  // Critical: preserve facial expressions when motions play (matches Desktop Pet LAppModel)
  if (window.PIXI && PIXI.live2d && PIXI.live2d.config) {
    PIXI.live2d.config.preserveExpressionOnMotion = true;
  }

  // Device pixel ratio: natively match iPhone OLED 2x/3x screen for pristine crispness
  const dpr = Math.min(Math.max(window.devicePixelRatio || 2, 2), 3);

  const app = new PIXI.Application({
    view: canvas,
    autoStart: true,
    transparent: true,
    backgroundAlpha: 0,
    resolution: dpr,
    autoDensity: true,
    antialias: true,
    powerPreference: 'high-performance',
    width: window.innerWidth || 390,
    height: window.innerHeight || 844,
  });

  // 2. Framerate Management (60 FPS fluid mode vs 30/15 FPS battery saver)
  let is60FPSMode = true;
  let IDLE_FPS = 60;
  let ACTIVE_FPS = 60;
  app.ticker.maxFPS = 60;
  if (PIXI.Ticker && PIXI.Ticker.shared) {
    PIXI.Ticker.shared.maxFPS = 60;
  }

  let boostTimer = null;
  let targetMouthOpen = 0;
  let smoothedLipSync = 0;
  let isSpeakingAudio = false;
  let live2dModel = null;
  let currentOutfit = 'classic';

  function applyFPSMode(enabled) {
    is60FPSMode = !!enabled;
    if (is60FPSMode) {
      IDLE_FPS = 60;
      ACTIVE_FPS = 60;
      app.ticker.maxFPS = 60;
      if (PIXI.Ticker && PIXI.Ticker.shared) PIXI.Ticker.shared.maxFPS = 60;
    } else {
      IDLE_FPS = 15;
      ACTIVE_FPS = 30;
      app.ticker.maxFPS = IDLE_FPS;
      if (PIXI.Ticker && PIXI.Ticker.shared) PIXI.Ticker.shared.maxFPS = IDLE_FPS;
    }
    console.log('[Live2D WebEngine] FPS mode updated. is60FPS:', is60FPSMode, 'targetFPS:', app.ticker.maxFPS);
  }

  function wakeToActiveFPS(durationSeconds = 3.5) {
    if (is60FPSMode) {
      app.ticker.maxFPS = 60;
      if (PIXI.Ticker && PIXI.Ticker.shared) PIXI.Ticker.shared.maxFPS = 60;
      return;
    }
    app.ticker.maxFPS = ACTIVE_FPS;
    if (PIXI.Ticker && PIXI.Ticker.shared) PIXI.Ticker.shared.maxFPS = ACTIVE_FPS;
    if (boostTimer) {
      clearTimeout(boostTimer);
    }
    boostTimer = setTimeout(() => {
      if (!isSpeakingAudio && smoothedLipSync <= 0.01) {
        app.ticker.maxFPS = IDLE_FPS;
        if (PIXI.Ticker && PIXI.Ticker.shared) PIXI.Ticker.shared.maxFPS = IDLE_FPS;
      }
    }, durationSeconds * 1000);
  }

  // =========================================================================
  // 3. Fast O(1) Core Parameter Helpers (cleared on outfit switch)
  // =========================================================================
  let cachedCore = null;
  let paramIndexCache = Object.create(null);

  function getParamIndex(core, id) {
    if (!core) return -1;
    if (core !== cachedCore) {
      cachedCore = core;
      paramIndexCache = Object.create(null);
    }
    if (paramIndexCache[id] !== undefined) return paramIndexCache[id];
    let idx = -1;
    try {
      if (typeof core.getParameterIndex === 'function') {
        idx = core.getParameterIndex(id);
      }
    } catch (e) {
      idx = -1;
    }
    paramIndexCache[id] = idx;
    return idx;
  }

  function getCoreParam(core, id) {
    if (!core) return 0;
    const idx = getParamIndex(core, id);
    if (idx >= 0 && typeof core.getParameterValueByIndex === 'function') {
      return core.getParameterValueByIndex(idx);
    }
    if (typeof core.getParameterValueById === 'function') {
      try { return core.getParameterValueById(id); } catch (e) { return 0; }
    }
    return 0;
  }

  function setCoreParam(core, id, value) {
    if (!core) return;
    const idx = getParamIndex(core, id);
    if (idx >= 0 && typeof core.setParameterValueByIndex === 'function') {
      core.setParameterValueByIndex(idx, value, 1);
      return;
    }
    if (typeof core.setParameterValueById === 'function') {
      try { core.setParameterValueById(id, value); } catch (e) {}
    }
  }

  // =========================================================================
  // 4. Desktop Pet Biometric & Speech Gesture State (1:1 Port)
  // =========================================================================
  const HAND_R_IDS = Array.from({ length: 11 }, (_, i) => `PARAM_HAND_R_${String(i + 1).padStart(2, '0')}`);
  const HAND_L_IDS = Array.from({ length: 11 }, (_, i) => `PARAM_HAND_L_${String(i + 1).padStart(2, '0')}`);

  let lastInteractionTime = Date.now();
  let lastChatTime = 0;
  let isTouchNear = false;

  // Respiration state (natural 3.2s cycle; 4.8s deep breath when idle)
  let breathPhase = 0;
  let breathDuration = 3.2;
  let isBoredomDeepBreath = false;
  let lastBreathFrameTime = 0;
  let lastLipSyncFrameTime = 0;

  // Micro-saccades & Gaze aversion state
  let nextSaccadeTime = 0;
  const saccadeOffset = { x: 0, y: 0 };
  const targetSaccadeOffset = { x: 0, y: 0 };
  const gazeAversion = { x: 0, y: 0, targetX: 0, targetY: 0 };
  let aversionResetTimer = null;

  function triggerEmiliaAversion(type) {
    lastInteractionTime = Date.now();
    if (type === 'think') {
      gazeAversion.targetX = -0.45;
      gazeAversion.targetY = 0.35;
    } else {
      gazeAversion.targetX = 0.5;
      gazeAversion.targetY = -0.3;
    }
    if (aversionResetTimer) clearTimeout(aversionResetTimer);
    aversionResetTimer = setTimeout(() => {
      gazeAversion.targetX = 0;
      gazeAversion.targetY = 0;
    }, 1800);
  }

  // Formant vowel lip-sync state (A / I / U / E / O)
  let formantCycleTime = 0;
  let formantVowelIndex = 0;
  let isFormantSpeaking = false;
  let curMouthScale = 0;
  let curMouthScaleY = 0;
  let curMouthForm = 1.0;

  const FORMANT_MAP = [
    { name: 'A', scale: 0.05, scaleY: 0.25, form: 0.2 },
    { name: 'I', scale: 0.55, scaleY: -0.20, form: 1.2 },
    { name: 'U', scale: -0.65, scaleY: -0.15, form: 0.0 },
    { name: 'E', scale: 0.32, scaleY: 0.05, form: 0.9 },
    { name: 'O', scale: -0.28, scaleY: 0.35, form: 0.1 }
  ];

  // Touch / Headpat spring physics state
  const patState = {
    targetEyeClose: 0,
    curEyeClose: 0,
    targetTiltZ: 0,
    curTiltZ: 0,
    targetBlush: 0,
    curBlush: 0,
    targetPosY: 0,
    curPosY: 0,
    targetSmile: 0,
    curSmile: 0,
    lastActiveTime: 0
  };

  // Speech Gesture Layer (exact port of emilia_biometric_enhancer.js)
  const speechGesture = {
    amp: 0, env: 0, level: 0, lastLoudAt: 0, lastFrame: 0, lastBeatAt: 0,
    nodTarget: 0, nod: 0, nodOffAt: 0,
    handSide: 0, handL: 0, handR: 0, handTargetL: 0, handTargetR: 0, handOffAt: 0,
    tilt: 0, tiltTarget: 0, lookX: 0, lookXTarget: 0, lookY: 0, lookYTarget: 0, nextPickAt: 0,
    sway: 0, brow: 0, browTarget: 0
  };

  function chase(cur, target, dt, tau) {
    return cur + (target - cur) * (1 - Math.exp(-dt / tau));
  }

  function sanitizeHands(core) {
    let maxR = -1, bestR = -1;
    for (let i = 0; i < 11; i++) {
      const v = getCoreParam(core, HAND_R_IDS[i]);
      if (v > maxR) { maxR = v; bestR = i; }
    }
    if (maxR > 0.05) {
      for (let i = 0; i < 11; i++) {
        setCoreParam(core, HAND_R_IDS[i], i === bestR ? 1.0 : 0.0);
      }
    }

    let maxL = -1, bestL = -1;
    for (let i = 0; i < 11; i++) {
      const v = getCoreParam(core, HAND_L_IDS[i]);
      if (v > maxL) { maxL = v; bestL = i; }
    }
    if (maxL > 0.05) {
      for (let i = 0; i < 11; i++) {
        setCoreParam(core, HAND_L_IDS[i], i === bestL ? 1.0 : 0.0);
      }
    }
  }

  function applySpeechGestures(model, core, now) {
    const g = speechGesture;
    const dt = g.lastFrame > 0 ? Math.min(0.05, Math.max(0.001, (now - g.lastFrame) / 1000)) : 0.016;
    g.lastFrame = now;

    const level = Math.max(0, Math.min(1, smoothedLipSync));
    g.level = level;
    if (level > 0.08) g.lastLoudAt = now;
    const speaking = isSpeakingAudio || (now - g.lastLoudAt) < 450;

    // Attenuate additive gestures while an explicit keyframe motion (priority > 1) is playing
    // so they enrich rather than fight it; expand to full 1.0x when keyframe ends during long speech!
    let ampTarget = speaking ? 1 : 0;
    try {
      const pr = model && model.internalModel && model.internalModel.motionManager
        ? (model.internalModel.motionManager.state.currentPriority || 0)
        : 0;
      if (pr > 1) ampTarget *= 0.45;
    } catch (e) {}

    g.amp = chase(g.amp, ampTarget, dt, ampTarget > g.amp ? 0.25 : 0.5);
    if (g.amp < 0.005 && !speaking) {
      g.nod = g.handL = g.handR = g.tilt = g.lookX = g.lookY = g.brow = 0;
      return;
    }

    // Accent / stress beat detection: instant energy spikes above slow envelope
    g.env = chase(g.env, level, dt, 0.35);
    if (level > g.env * 1.35 + 0.1 && level > 0.2 && (now - g.lastBeatAt) > 480) {
      g.lastBeatAt = now;
      g.nodTarget = 1;
      g.nodOffAt = now + 110;
      g.browTarget = 1;
      g.handSide = (g.handSide + 1) % 3; // 0: Left, 1: Right, 2: Both
      const useL = g.handSide !== 1;
      const useR = g.handSide !== 0;
      g.handTargetL = useL ? 1 : 0;
      g.handTargetR = useR ? 1 : 0;
      g.handOffAt = now + 170;
    }
    if (now > g.nodOffAt) { g.nodTarget = 0; g.browTarget = 0; }
    if (now > g.handOffAt) { g.handTargetL = 0; g.handTargetR = 0; }

    // Organic gaze & head tilt drift every 1.6~3.4s while speaking
    if (now > g.nextPickAt) {
      g.tiltTarget = (Math.random() - 0.5) * 7;
      g.lookXTarget = (Math.random() - 0.5) * 8;
      g.lookYTarget = (Math.random() - 0.3) * 4;
      g.nextPickAt = now + 1600 + Math.random() * 1800;
    }

    g.nod = chase(g.nod, g.nodTarget, dt, g.nodTarget > g.nod ? 0.07 : 0.22);
    g.handL = chase(g.handL, g.handTargetL, dt, g.handTargetL > g.handL ? 0.1 : 0.3);
    g.handR = chase(g.handR, g.handTargetR, dt, g.handTargetR > g.handR ? 0.1 : 0.3);
    g.brow = chase(g.brow, g.browTarget, dt, 0.15);
    g.tilt = chase(g.tilt, g.tiltTarget, dt, 0.6);
    g.lookX = chase(g.lookX, g.lookXTarget, dt, 0.7);
    g.lookY = chase(g.lookY, g.lookYTarget, dt, 0.7);
    g.sway += dt * (Math.PI * 2) / 3.1;

    const a = g.amp;
    const add = (id, v) => setCoreParam(core, id, getCoreParam(core, id) + v);
    add('PARAM_ANGLE_Y', a * (-3.4 * g.nod + 2.0 * level + g.lookY));
    add('PARAM_ANGLE_X', a * g.lookX);
    add('PARAM_ANGLE_Z', a * g.tilt);
    add('PARAM_BODY_ANGLE_Z', a * (0.35 * g.tilt + 1.1 * Math.sin(g.sway)));
    add('PARAM_BODY_ANGLE_X', a * 0.3 * g.lookX);
    add('PARAM_SHOLDER_POSITION', a * (0.8 * level + 0.6 * g.nod));
    add('PARAM_ARM_L_ROTATE', a * 7 * g.handL);
    add('PARAM_ARM_R_ROTATE', a * 7 * g.handR);
    add('PARAM_HAND_L_ROTATE', a * 9 * g.handL);
    add('PARAM_HAND_R_ROTATE', a * -9 * g.handR);
    add('PARAM_BROW_L_Y', a * 0.28 * g.brow);
    add('PARAM_BROW_R_Y', a * 0.28 * g.brow);
  }

  function applyBiometrics(model, core) {
    const now = Date.now();

    // 1. Asymmetric lip-sync smoothing (fast attack 20.0, damped release 12.0)
    const dtLip = lastLipSyncFrameTime > 0 ? Math.min(0.05, Math.max(0.001, (now - lastLipSyncFrameTime) / 1000)) : 0.016;
    lastLipSyncFrameTime = now;
    const lerpSpeed = targetMouthOpen > smoothedLipSync ? 20.0 : 12.0;
    smoothedLipSync += (targetMouthOpen - smoothedLipSync) * Math.min(1.0, dtLip * lerpSpeed);
    if (smoothedLipSync < 0.008 && targetMouthOpen <= 0.008) {
      smoothedLipSync = 0.0;
    }
    setCoreParam(core, 'PARAM_MOUTH_OPEN_Y', smoothedLipSync);
    setCoreParam(core, 'ParamMouthOpenY', smoothedLipSync);

    // 2. Discrete hand mesh sanitizer (prevents semi-transparent ghost hands during cross-fades)
    sanitizeHands(core);

    // 3. Touch / headpat spring physics damping
    if (now - patState.lastActiveTime > 180) {
      patState.targetEyeClose = 0;
      patState.targetTiltZ = 0;
      patState.targetPosY = 0;
    }
    if (now - patState.lastActiveTime > 1200) {
      patState.targetBlush = 0;
    }
    if (now - patState.lastActiveTime > 1800) {
      patState.targetSmile = 0;
    }
    patState.curSmile += (patState.targetSmile - patState.curSmile) * 0.12;
    if (patState.curSmile > 0.02) {
      const k = patState.curSmile;
      const lerpParam = (id, target) => {
        const b = getCoreParam(core, id);
        setCoreParam(core, id, b + (target - b) * k);
      };
      lerpParam('PARAM_MOUTH_FORM_01', 1.0);
      lerpParam('PARAM_MOUTH_POS_Y', 0.3);
      lerpParam('PARAM_MOUTH_SCALE', 0);
      lerpParam('PARAM_MOUTH_SCALE_Y', 0);
      lerpParam('PARAM_BROW_L_FORM', 0.3);
      lerpParam('PARAM_BROW_R_FORM', 0.3);
      lerpParam('PARAM_EYE_L_SMILE', 0.5);
      lerpParam('PARAM_EYE_R_SMILE', 0.5);
    }
    patState.curEyeClose += (patState.targetEyeClose - patState.curEyeClose) * 0.15;
    patState.curTiltZ += (patState.targetTiltZ - patState.curTiltZ) * 0.15;
    patState.curBlush += (patState.targetBlush - patState.curBlush) * 0.12;
    patState.curPosY += (patState.targetPosY - patState.curPosY) * 0.12;

    if (patState.curEyeClose > 0.01) {
      const baseEyeL = getCoreParam(core, 'PARAM_EYE_L_OPEN');
      const baseEyeR = getCoreParam(core, 'PARAM_EYE_R_OPEN');
      setCoreParam(core, 'PARAM_EYE_L_OPEN', baseEyeL * (1 - patState.curEyeClose) + 0.28 * patState.curEyeClose);
      setCoreParam(core, 'PARAM_EYE_R_OPEN', baseEyeR * (1 - patState.curEyeClose) + 0.28 * patState.curEyeClose);
      if (patState.curEyeClose > 0.2) {
        setCoreParam(core, 'PARAM_EYE_L_SMILE', Math.max(getCoreParam(core, 'PARAM_EYE_L_SMILE'), patState.curEyeClose * 0.85));
        setCoreParam(core, 'PARAM_EYE_R_SMILE', Math.max(getCoreParam(core, 'PARAM_EYE_R_SMILE'), patState.curEyeClose * 0.85));
      }
    }
    if (Math.abs(patState.curTiltZ) > 0.05) {
      setCoreParam(core, 'PARAM_ANGLE_Z', getCoreParam(core, 'PARAM_ANGLE_Z') + patState.curTiltZ);
      setCoreParam(core, 'PARAM_BODY_ANGLE_Z', getCoreParam(core, 'PARAM_BODY_ANGLE_Z') + patState.curTiltZ * 0.35);
    }
    if (patState.curBlush > 0.01) {
      setCoreParam(core, 'PARAM_CHEEK_01', Math.max(getCoreParam(core, 'PARAM_CHEEK_01'), patState.curBlush));
    }
    if (Math.abs(patState.curPosY) > 0.05) {
      setCoreParam(core, 'PARAM_POSITION_Y', getCoreParam(core, 'PARAM_POSITION_Y') + patState.curPosY);
    }

    // 4. Organic respiration (additive shoulder rise + upper body fluffy lag + chest breath)
    if (!isBoredomDeepBreath) {
      breathDuration += (3.2 - breathDuration) * 0.05;
    }
    const dtBreath = lastBreathFrameTime > 0 ? Math.min(0.1, Math.max(0.001, (now - lastBreathFrameTime) / 1000)) : 0.016;
    lastBreathFrameTime = now;
    breathPhase = (breathPhase + dtBreath * ((Math.PI * 2) / Math.max(0.5, breathDuration))) % (Math.PI * 2);
    const breathWave = Math.sin(breathPhase);
    const breathLag = Math.sin(breathPhase - 0.75);
    setCoreParam(core, 'PARAM_SHOLDER_POSITION', getCoreParam(core, 'PARAM_SHOLDER_POSITION') + breathWave * 2.2);
    setCoreParam(core, 'PARAM_UPPER_BODY_FLUFFY', getCoreParam(core, 'PARAM_UPPER_BODY_FLUFFY') + breathLag * 0.28);
    setCoreParam(core, 'PARAM_BREATH', (breathWave + 1.0) * 0.5);

    // 5. Micro-saccades & gaze aversion (keeps eyes genuinely alive!)
    if (now > nextSaccadeTime) {
      targetSaccadeOffset.x = (Math.random() - 0.5) * 0.07;
      targetSaccadeOffset.y = (Math.random() - 0.5) * 0.04;
      nextSaccadeTime = now + 240 + Math.random() * 260;
    }
    saccadeOffset.x += (targetSaccadeOffset.x - saccadeOffset.x) * 0.15;
    saccadeOffset.y += (targetSaccadeOffset.y - saccadeOffset.y) * 0.15;
    gazeAversion.x += (gazeAversion.targetX - gazeAversion.x) * 0.07;
    gazeAversion.y += (gazeAversion.targetY - gazeAversion.y) * 0.07;

    const rawEyeL = getCoreParam(core, 'PARAM_EYE_L_OPEN');
    const eyeWeight = Math.min(1.0, Math.max(0.0, (rawEyeL - 0.22) / 0.5));
    setCoreParam(core, 'PARAM_EYE_BALL_X', getCoreParam(core, 'PARAM_EYE_BALL_X') + (saccadeOffset.x + gazeAversion.x) * eyeWeight);
    setCoreParam(core, 'PARAM_EYE_BALL_Y', getCoreParam(core, 'PARAM_EYE_BALL_Y') + (saccadeOffset.y + gazeAversion.y) * eyeWeight);

    // 6. Speech Gesture Layer (nodding, eyebrow accent, arm/hand gestures, head tilt & sway)
    try {
      applySpeechGestures(model, core, now);
    } catch (e) {}

    // 7. Vowel Formant Lip Sync (A / I / U / E / O natural mouth shapes)
    const mouthOpen = smoothedLipSync;
    const enterThreshold = 0.14;
    const exitThreshold = 0.08;
    if (isFormantSpeaking ? mouthOpen > exitThreshold : mouthOpen > enterThreshold) {
      isFormantSpeaking = true;
      if (now - formantCycleTime > 180) {
        formantVowelIndex = (formantVowelIndex + 1) % FORMANT_MAP.length;
        formantCycleTime = now;
      }
      const vowel = FORMANT_MAP[formantVowelIndex];
      const intensity = Math.min(1.0, mouthOpen * 1.2);
      curMouthScale += (vowel.scale * intensity - curMouthScale) * 0.25;
      curMouthScaleY += (vowel.scaleY * intensity - curMouthScaleY) * 0.25;
      curMouthForm += ((1.0 + vowel.form * intensity) - curMouthForm) * 0.25;
      setCoreParam(core, 'PARAM_MOUTH_SCALE', curMouthScale);
      setCoreParam(core, 'PARAM_MOUTH_SCALE_Y', curMouthScaleY);
      setCoreParam(core, 'PARAM_MOUTH_FORM_01', curMouthForm);
    } else if (isFormantSpeaking) {
      curMouthScale += (0 - curMouthScale) * 0.25;
      curMouthScaleY += (0 - curMouthScaleY) * 0.25;
      curMouthForm += (1.0 - curMouthForm) * 0.25;
      setCoreParam(core, 'PARAM_MOUTH_SCALE', curMouthScale);
      setCoreParam(core, 'PARAM_MOUTH_SCALE_Y', curMouthScaleY);
      setCoreParam(core, 'PARAM_MOUTH_FORM_01', curMouthForm);
      if (Math.abs(curMouthScale) < 0.01 && Math.abs(curMouthScaleY) < 0.01 && Math.abs(curMouthForm - 1.0) < 0.01) {
        isFormantSpeaking = false;
        setCoreParam(core, 'PARAM_MOUTH_SCALE', 0);
        setCoreParam(core, 'PARAM_MOUTH_SCALE_Y', 0);
        setCoreParam(core, 'PARAM_MOUTH_FORM_01', 1.0);
      }
    }
  }

  // Idle boredom micro-cues (exact port of emilia_biometric_enhancer.js)
  setInterval(() => {
    if (!live2dModel || isSpeakingAudio) return;
    const idleSec = Math.floor((Date.now() - lastInteractionTime) / 1000);
    if (idleSec === 16) {
      gazeAversion.targetX = 0.55;
      gazeAversion.targetY = 0.25;
      setTimeout(() => { gazeAversion.targetX = 0; gazeAversion.targetY = 0; }, 2200);
    } else if (idleSec === 41) {
      isBoredomDeepBreath = true;
      breathDuration = 4.8;
      setTimeout(() => {
        isBoredomDeepBreath = false;
        breathDuration = 3.2;
      }, 3500);
    } else if (idleSec >= 80 && idleSec % 30 === 0) {
      gazeAversion.targetX = -0.3;
      gazeAversion.targetY = -0.35;
      setTimeout(() => { gazeAversion.targetX = 0; gazeAversion.targetY = 0; }, 2500);
    }
  }, 1000);

  // =========================================================================
  // 5. Desktop Pet Motion Scheduler (LAppModel IdleMacro + emiliaOnChunkStart)
  // =========================================================================
  const MOTION_PRIORITY_IDLE = 1;
  const MOTION_PRIORITY_NORMAL = 2;
  const MOTION_PRIORITY_FORCE = 3;

  let userTimeSeconds = 0;
  let lastSchedulerMs = Date.now();
  let idleState = 'none'; // 'none' | 'base' | 'macro' | 'other'
  let nextMacroAt = 0;
  let macroEndAt = 0;
  const lastMotionIndex = Object.create(null);

  let lastMotionName = '';
  let lastMotionTriggerTime = 0;
  let lastNonIdleStartTime = 0;
  let chunkMotionTimers = [];
  let settleTimer = null;

  function clearChunkMotionTimers() {
    for (const id of chunkMotionTimers) {
      clearTimeout(id);
    }
    chunkMotionTimers = [];
  }

  function clearSettleTimer() {
    if (settleTimer) {
      clearTimeout(settleTimer);
      settleTimer = null;
    }
  }

  function getMotionCount(model, group) {
    try {
      const defs = model && model.internalModel && model.internalModel.motionManager && model.internalModel.motionManager.definitions;
      return (defs && Array.isArray(defs[group])) ? defs[group].length : 0;
    } catch (e) {
      return 0;
    }
  }

  function pickMotionIndexNoRepeat(model, group) {
    const count = getMotionCount(model, group);
    if (count <= 1) return 0;
    const last = lastMotionIndex[group];
    let no = Math.floor(Math.random() * count);
    if (no === last) {
      no = (no + 1 + Math.floor(Math.random() * (count - 1))) % count;
    }
    lastMotionIndex[group] = no;
    return no;
  }

  // Situational IdleMacro picker (exact port of LAppModel.pickSituationalMacroIndex)
  // 0: Appeal | 1: Pride | 2: Thinking | 3: Navi | 4: Shame | 5: Happy
  function pickSituationalMacroIndex(model) {
    const totalCount = getMotionCount(model, 'IdleMacro');
    if (totalCount <= 0) return 0;

    const hour = new Date().getHours();
    const isNight = hour >= 23 || hour < 6;
    const secSinceChat = lastChatTime > 0 ? (Date.now() - lastChatTime) / 1000 : 9999;
    const isPostChat = secSinceChat < 45;
    const isLongIdle = secSinceChat > 180;

    let candidates = [1, 2]; // Default: Pride, Thinking
    if (isNight) {
      candidates = [1, 2]; // Calm late-night companionship
    } else if (isTouchNear) {
      candidates = [0, 4]; // Appeal, Shame
    } else if (isPostChat) {
      candidates = [0, 5]; // Appeal, Happy (post-chat warmth)
    } else if (isLongIdle) {
      candidates = [0, 3]; // Appeal, Navi (gentle wave/attention)
    } else {
      candidates = [1, 2]; // Pride, Thinking
    }

    const valid = candidates.filter((i) => i < totalCount);
    if (valid.length === 0) return pickMotionIndexNoRepeat(model, 'IdleMacro');

    const last = lastMotionIndex['IdleMacro'];
    let chosen = valid[Math.floor(Math.random() * valid.length)];
    if (chosen === last && valid.length > 1) {
      const rest = valid.filter((i) => i !== last);
      chosen = rest[Math.floor(Math.random() * rest.length)];
    }
    lastMotionIndex['IdleMacro'] = chosen;
    return chosen;
  }

  function onMotionStarted(model, group, index) {
    const mm = model && model.internalModel && model.internalModel.motionManager;
    if (!mm) return;

    const isIdleBase = group === 'Idle';
    const isMacro = group === 'IdleMacro';

    // Exact LAppModel rule: Idle & IdleMacro always sit at PriorityIdle so they never block speech/emotion!
    if (isIdleBase || isMacro) {
      if (mm.state) {
        mm.state.currentPriority = MOTION_PRIORITY_IDLE;
      }
    }

    let dur = 3.2;
    try {
      const m = mm.motionGroups && mm.motionGroups[group] && mm.motionGroups[group][index];
      if (m && typeof m.getDuration === 'function') {
        const d = m.getDuration();
        if (d > 0) dur = d;
      }
    } catch (e) {}

    if (isIdleBase) {
      idleState = 'base';
      const hour = new Date().getHours();
      const isNight = hour >= 23 || hour < 6;
      // Exact LAppModel cadence: 60~120s at night, 35~75s daytime (75%+ calm breathing)
      const interval = isNight ? (60 + Math.random() * 60) : (35 + Math.random() * 40);
      nextMacroAt = userTimeSeconds + interval;
    } else if (isMacro) {
      idleState = 'macro';
      macroEndAt = userTimeSeconds + (dur > 0 ? dur : 3.2);
    } else {
      idleState = 'other';
      lastNonIdleStartTime = Date.now();
    }
  }

  function updateIdleScheduler(model) {
    if (!model || !model.internalModel || !model.internalModel.motionManager) return;
    const now = Date.now();
    const dt = Math.min(0.1, Math.max(0.001, (now - lastSchedulerMs) / 1000));
    lastSchedulerMs = now;
    userTimeSeconds += dt;

    const mm = model.internalModel.motionManager;
    const currentPriority = (mm.state && mm.state.currentPriority) || 0;
    const hour = new Date().getHours();
    const isNight = hour >= 23 || hour < 6;

    if (idleState === 'base') {
      if (
        !isSpeakingAudio &&
        userTimeSeconds >= nextMacroAt &&
        getMotionCount(model, 'IdleMacro') > 0 &&
        currentPriority <= MOTION_PRIORITY_IDLE
      ) {
        const interval = isNight ? (60 + Math.random() * 60) : (35 + Math.random() * 40);
        nextMacroAt = userTimeSeconds + interval;
        const idx = pickSituationalMacroIndex(model);
        wakeToActiveFPS(5.0);
        model.motion('IdleMacro', idx, MOTION_PRIORITY_NORMAL);
      }
    } else if (idleState === 'macro') {
      // Exact LAppModel: 1.2s before macro finishes, S-curve cross-fade back into Idle_0
      if (userTimeSeconds >= macroEndAt - 1.2) {
        idleState = 'base';
        try {
          const idleMotion = mm.motionGroups && mm.motionGroups['Idle'] && mm.motionGroups['Idle'][0];
          if (idleMotion) {
            idleMotion.setFadeInTime(1.2);
            idleMotion.setFadeOutTime(1.2);
          }
        } catch (e) {}
        model.motion('Idle', 0, MOTION_PRIORITY_NORMAL);
      }
    }
  }

  function patchModelMotionEngine(model) {
    if (!model || !model.internalModel) return;
    const internal = model.internalModel;
    const mm = internal.motionManager;

    if (mm && !mm.__emiliaPatched) {
      mm.__emiliaPatched = true;

      // 1. Patch _startMotion: REMOVE hard stopAllMotions() so motions smoothly cross-fade (exact LAppModel)
      mm._startMotion = function (motion, onFinish) {
        if (motion && typeof motion.setFinishedMotionHandler === 'function') {
          motion.setFinishedMotionHandler(onFinish);
        }
        return this.queueManager.startMotion(motion, false, performance.now());
      };

      // 2. Patch createMotion: ALWAYS respect FadeInTime/FadeOutTime defined in Character.model3.json (e.g. 1.2s for IdleMacro)
      const origCreateMotion = mm.createMotion.bind(mm);
      mm.createMotion = function (data, group, definition) {
        const motion = origCreateMotion(data, group, definition);
        if (motion && definition) {
          if (typeof definition.FadeInTime === 'number' && definition.FadeInTime > 0) {
            motion.setFadeInTime(definition.FadeInTime);
          }
          if (typeof definition.FadeOutTime === 'number' && definition.FadeOutTime > 0) {
            motion.setFadeOutTime(definition.FadeOutTime);
          }
        }
        return motion;
      };

      // 3. Track motion start for IdleMacro scheduler & priority demotion
      mm.on('motionStart', (group, index) => {
        onMotionStarted(model, group, index);
      });
    }

    // 4. Hook right BEFORE coreModel.update() (vertex calculation) — exact LAppModel pipeline!
    if (!internal.__emiliaBiometricsAttached) {
      internal.__emiliaBiometricsAttached = true;
      internal.on('afterMotionUpdate', () => {
        if (model === live2dModel) {
          updateIdleScheduler(model);
        }
      });
      internal.on('beforeModelUpdate', () => {
        if (model === live2dModel && internal.coreModel) {
          applyBiometrics(model, internal.coreModel);
        }
      });
    }

    // Kick off initial Idle_0 state cleanly
    idleState = 'base';
    const hour = new Date().getHours();
    const isNight = hour >= 23 || hour < 6;
    nextMacroAt = userTimeSeconds + (isNight ? (45 + Math.random() * 45) : (20 + Math.random() * 25));
  }

  // Motion playback helpers (1:1 port of emilia_biometric_enhancer.js)
  function playMotionVariant(group, fixedIndex, priority = MOTION_PRIORITY_FORCE) {
    if (!live2dModel) return;
    wakeToActiveFPS(4.5);
    const idx = (typeof fixedIndex === 'number' && fixedIndex >= 0)
      ? fixedIndex
      : pickMotionIndexNoRepeat(live2dModel, group);
    try {
      live2dModel.motion(group, idx, priority);
    } catch (e) {
      console.warn('[Live2D WebEngine] playMotionVariant warning:', e);
    }
  }

  function settleToIdle(fadeInSec = 1.0) {
    if (!live2dModel) return;
    clearSettleTimer();
    try {
      const mm = live2dModel.internalModel && live2dModel.internalModel.motionManager;
      if (mm && mm.state && mm.state.currentGroup === 'Idle') {
        return; // Already smoothly idling
      }
      const idleMotion = mm && mm.motionGroups && mm.motionGroups['Idle'] && mm.motionGroups['Idle'][0];
      if (idleMotion && typeof idleMotion.setFadeInTime === 'function') {
        idleMotion.setFadeInTime(fadeInSec);
      }
      wakeToActiveFPS(2.5);
      live2dModel.motion('Idle', 0, MOTION_PRIORITY_FORCE);
      console.log('[Live2D WebEngine] Smoothly settled to Idle posture');
    } catch (e) {
      console.warn('[Live2D WebEngine] settleToIdle warning:', e);
    }
  }

  function triggerMotionByTag(tag, force = false) {
    if (!live2dModel || !tag) return;
    const norm = String(tag).toLowerCase().trim();
    const now = Date.now();
    if (!force && norm === lastMotionName && (now - lastMotionTriggerTime < 1500)) {
      return;
    }
    lastMotionName = norm;
    lastMotionTriggerTime = now;

    console.log('[Live2D WebEngine] triggerMotionByTag:', norm, 'force:', force);

    if (norm.includes('idle') || norm.includes('wait') || norm.includes('待機') || norm.includes('放鬆') || norm.includes('停')) {
      settleToIdle(1.0);
    } else if (norm.includes('jump') || norm.includes('跳')) {
      if (norm.includes('double')) {
        playMotionVariant('Surprise', 1, MOTION_PRIORITY_FORCE);
      } else {
        playMotionVariant('Happy', 2, MOTION_PRIORITY_FORCE);
      }
    } else if (norm.includes('appeal') || norm.includes('撒嬌') || norm.includes('adoration') || norm.includes('love')) {
      playMotionVariant('Appeal');
    } else if (norm.includes('shysmile') || norm.includes('嬌羞')) {
      playMotionVariant('ShySmile');
    } else if (norm.includes('shy') || norm.includes('害羞') || norm.includes('blush') || norm.includes('shame') || norm.includes('tsundere')) {
      playMotionVariant('Shy');
    } else if (norm.includes('think') || norm.includes('思考') || norm.includes('puzzle') || norm.includes('jitome') || norm.includes('doubt')) {
      playMotionVariant('Thinking');
      triggerEmiliaAversion('think');
    } else if (norm.includes('pout') || norm.includes('angry') || norm.includes('氣惱') || norm.includes('anger')) {
      playMotionVariant('Angry');
    } else if (norm.includes('pride') || norm.includes('自豪') || norm.includes('smug')) {
      playMotionVariant('Pride');
    } else if (norm.includes('serious') || norm.includes('嚴肅') || norm.includes('認真')) {
      playMotionVariant('Serious');
    } else if (norm.includes('sad') || norm.includes('哀傷') || norm.includes('cry') || norm.includes('tears') || norm.includes('upset')) {
      playMotionVariant('Sad');
    } else if (norm.includes('surprise') || norm.includes('shock') || norm.includes('驚')) {
      playMotionVariant('Surprise');
    } else if (norm.includes('joy') || norm.includes('happy') || norm.includes('smile') || norm.includes('雀躍')) {
      playMotionVariant('Happy');
    } else if (norm.includes('talk') || norm.includes('交談')) {
      playMotionVariant('Talk', undefined, MOTION_PRIORITY_FORCE);
    }
  }

  // Exact Desktop Pet chunk-start orchestrator (use-audio-task.ts + emiliaOnChunkStart)
  function onChunkStart(rawText, durationMs) {
    clearChunkMotionTimers();
    clearSettleTimer();
    lastChatTime = Date.now();
    lastInteractionTime = Date.now();
    isSpeakingAudio = true;
    wakeToActiveFPS(5.0);

    const text = String(rawText || '');
    const tags = [...text.matchAll(/\[motion:([a-zA-Z0-9_-]+)\]/gi)].map((m) => m[1].toLowerCase());
    const visible = text.replace(/\[[^\]]+\]/g, '').replace(/[()（）]/g, '').trim().length;
    const estMs = (typeof durationMs === 'number' && durationMs > 0)
      ? Math.max(1500, Math.min(15000, durationMs))
      : Math.max(1500, Math.min(12000, visible * 190));

    const isIdleTag = (t) => t.includes('idle') || t.includes('wait') || t.includes('待機');
    const playable = tags.filter((t) => !isIdleTag(t));

    if (playable.length > 0) {
      // Exact emiliaOnChunkStart: play tagged motions spread evenly across the chunk!
      playable.forEach((t, i) => {
        if (i === 0) {
          triggerMotionByTag(t, false);
        } else {
          const timerId = setTimeout(() => triggerMotionByTag(t, true), (estMs * i) / playable.length);
          chunkMotionTimers.push(timerId);
        }
      });
    } else if (live2dModel) {
      // Matches use-audio-task.ts fallback: start Talk at PriorityNormal (2) —
      // plays naturally if currently Idle, but NEVER cuts off an ongoing PriorityForce (3) motion!
      const talkIdx = pickMotionIndexNoRepeat(live2dModel, 'Talk');
      live2dModel.motion('Talk', talkIdx, MOTION_PRIORITY_NORMAL);
    }

    if (tags.length > 0 && isIdleTag(tags[tags.length - 1])) {
      settleTimer = setTimeout(() => {
        if (!isSpeakingAudio) settleToIdle(1.0);
      }, estMs);
    }
  }

  // Called ONLY when the ENTIRE conversation turn finishes (backend-synth-complete + queue empty)
  function onPlaybackComplete() {
    clearChunkMotionTimers();
    clearSettleTimer();
    isSpeakingAudio = false;
    targetMouthOpen = 0;

    // Give any just-started emotional motion at least 2.2s to shine before smoothly gliding to Idle,
    // and minimum 300ms grace period (matches desktop pet frontend-playback-complete -> 300ms settleToIdle)
    const elapsedSinceMotion = Date.now() - lastNonIdleStartTime;
    const minGrace = 300;
    const minMotionHold = 2200;
    const delayMs = (idleState === 'other' && elapsedSinceMotion < minMotionHold)
      ? Math.max(minGrace, minMotionHold - elapsedSinceMotion)
      : minGrace;

    settleTimer = setTimeout(() => {
      if (!isSpeakingAudio) {
        settleToIdle(1.2);
      }
    }, delayMs);
  }

  function onInterrupt() {
    clearChunkMotionTimers();
    clearSettleTimer();
    isSpeakingAudio = false;
    targetMouthOpen = 0;
    settleToIdle(0.6);
  }

  // =========================================================================
  // 6. Model Loading & Layout
  // =========================================================================
  function layoutModel() {
    if (!live2dModel) return;
    const w = window.innerWidth || 390;
    const h = window.innerHeight || 844;
    if (w <= 0 || h <= 0) return;
    app.renderer.resize(w, h);

    if (live2dModel.anchor && typeof live2dModel.anchor.set === 'function') {
      live2dModel.anchor.set(0.5, 0);
    }

    const origH = (live2dModel.internalModel && live2dModel.internalModel.originalHeight) || 4500;
    const scale = (h * 1.05) / origH;
    live2dModel.scale.set(scale);

    live2dModel.x = w / 2;
    live2dModel.y = h * 0.07;
  }

  try {
    live2dModel = await PIXI.live2d.Live2DModel.from('model/Character.model3.json', {
      autoInteract: false,
    });

    app.stage.addChild(live2dModel);
    window.__model = live2dModel;
    window.__app = app;

    patchModelMotionEngine(live2dModel);
    layoutModel();
    window.addEventListener('resize', layoutModel);
    window.addEventListener('orientationchange', layoutModel);
    setTimeout(layoutModel, 100);
    setTimeout(layoutModel, 500);
    setTimeout(layoutModel, 1200);

    // =========================================================================
    // 7. v2.6.0 Intimacy Touch Particles & Biometric Spring Touch Feedback
    // =========================================================================
    let currentIntimacyScore = 312;

    function setIntimacyScore(score) {
      currentIntimacyScore = Math.max(0, Number(score) || 0);
      console.log('[Live2D WebEngine] Synchronized intimacyScore:', currentIntimacyScore);
    }

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
      } catch (err) {}
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

    const TOUCH_PARTS = {
      head: {
        name: '撫摸銀髮 (頭部)',
        minScore: 0,
        minLevel: 1,
        levelName: '初識同伴',
        motionTag: 'shysmile',
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
        motionTag: 'shy',
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
        motionTag: 'think',
        expression: 'exp_01_subtle_smile',
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
        motionTag: 'appeal',
        expression: 'exp_02_happy_big',
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
        motionTag: 'appeal',
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
        motionTag: 'happy',
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
      isTouchNear = true;
      lastInteractionTime = Date.now();
      wakeToActiveFPS(4.0);

      const target = detectTouchPart(e.clientX, e.clientY);
      activeTouchArea = target;
      const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
      const isUnlocked = currentIntimacyScore >= def.minScore;

      // Apply immediate tactile spring physics (squinting happy eyes & rosy blush when headpatting!)
      if (isUnlocked && target === 'head') {
        patState.targetEyeClose = currentIntimacyScore >= 450 ? 0.8 : 0.7;
        patState.targetBlush = 1.0;
        patState.targetSmile = currentIntimacyScore >= 450 ? 1.0 : 0.7;
        patState.targetTiltZ = (e.clientX < (window.innerWidth / 2)) ? -4.5 : 4.5;
        patState.lastActiveTime = Date.now();
      } else if (isUnlocked && target === 'cheek') {
        patState.targetBlush = 0.85;
        patState.targetTiltZ = 6.0;
        patState.lastActiveTime = Date.now();
      }

      const pIcons = isUnlocked ? def.icons : ['🔒', '❓'];
      for (let i = 0; i < 3; i++) {
        spawnTouchParticle(e.clientX, e.clientY, pIcons[i % pIcons.length]);
      }

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
      lastInteractionTime = Date.now();
      const target = detectTouchPart(e.clientX, e.clientY);
      const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
      const isUnlocked = currentIntimacyScore >= def.minScore;

      // Continuous tactile headpat physics while stroking
      if (isUnlocked && target === 'head') {
        patState.targetEyeClose = currentIntimacyScore >= 450 ? 0.8 : 0.7;
        patState.targetBlush = 1.0;
        patState.targetSmile = currentIntimacyScore >= 450 ? 1.0 : 0.7;
        patState.targetTiltZ = Math.max(-7, Math.min(7, ((e.clientX - (window.innerWidth / 2)) / 80) * 5));
        patState.lastActiveTime = Date.now();
      }

      if (Math.random() < 0.3) {
        spawnTouchParticle(e.clientX, e.clientY, isUnlocked ? '✨' : '🔒');
      }

      if (target !== activeTouchArea) {
        activeTouchArea = target;
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
      setTimeout(() => { isTouchNear = false; }, 12000);
      lastInteractionTime = Date.now();
      wakeToActiveFPS(4.0);

      const target = activeTouchArea || detectTouchPart(e.clientX, e.clientY);
      const def = TOUCH_PARTS[target] || TOUCH_PARTS.head;
      const isUnlocked = currentIntimacyScore >= def.minScore;

      if (isUnlocked) {
        if (target === 'head') {
          patState.targetEyeClose = currentIntimacyScore >= 450 ? 0.8 : 0.7;
          patState.targetBlush = 1.0;
          patState.targetSmile = currentIntimacyScore >= 450 ? 1.0 : 0.7;
          patState.lastActiveTime = Date.now();
          triggerMotionByTag(Math.random() > 0.3 ? 'shysmile' : 'appeal', true);
        } else {
          triggerMotionByTag(def.motionTag, true);
        }
        setExpression(def.expression);
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dTap) {
          window.webkit.messageHandlers.live2dTap.postMessage({
            area: target,
            text: def.toastUnlocked,
            isLocked: false
          });
        }
      } else {
        triggerMotionByTag('shy', true);
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
      isTouchNear = false;
    });

    // Notify Swift native side that engine is ready
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dReady) {
      window.webkit.messageHandlers.live2dReady.postMessage({ status: 'ready' });
    }
    console.log('[Live2D WebEngine] v3.0 Desktop-Pet Parity Motion & Biometric Engine ready.');

    // Expose setIntimacyScore cleanly on outer scope
    window.__setIntimacyScore = setIntimacyScore;
  } catch (error) {
    console.error('[Live2D WebEngine] Failed to initialize model:', error);
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.live2dError) {
      window.webkit.messageHandlers.live2dError.postMessage({ error: String(error) });
    }
  }

  // =========================================================================
  // 8. Swift Bridge Implementation
  // =========================================================================
  function setMouthOpen(value) {
    const val = Math.max(0, Math.min(1, Number(value) || 0));
    targetMouthOpen = val;
    if (val > 0.02) {
      wakeToActiveFPS(2.5);
    }
  }

  function triggerMotion(group, index, priority = MOTION_PRIORITY_FORCE) {
    wakeToActiveFPS(4.5);
    if (!live2dModel || !group) return;
    try {
      const idx = (typeof index === 'number' && index >= 0)
        ? index
        : pickMotionIndexNoRepeat(live2dModel, group);
      live2dModel.motion(group, idx, priority);
    } catch (e) {
      console.warn('[Live2D WebEngine] triggerMotion warning:', e);
    }
  }

  function setExpression(expId) {
    wakeToActiveFPS(3.0);
    if (!live2dModel) return;
    try {
      if (expId !== undefined && expId !== null && expId !== '') {
        // Resolve numeric strings (from backend model_dict.json emotionMap) to numeric indices!
        const resolved = (typeof expId === 'string' && /^\d+$/.test(expId.trim()))
          ? parseInt(expId.trim(), 10)
          : expId;
        live2dModel.expression(resolved);
      }
    } catch (e) {
      console.warn('[Live2D WebEngine] setExpression warning:', e);
    }
  }

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
      cachedCore = null;
      paramIndexCache = Object.create(null);
      app.stage.addChildAt(live2dModel, 0);
      window.__model = live2dModel;
      currentOutfit = outfitId;

      patchModelMotionEngine(live2dModel);
      layoutModel();
      wakeToActiveFPS(3.5);
      console.log('[Live2D WebEngine] Outfit switched successfully to:', outfitId);
    } catch (err) {
      console.error('[Live2D WebEngine] Failed to switch outfit:', err);
    }
  }

  function setPaused(isPaused) {
    if (isPaused) {
      if (app && app.ticker && app.ticker.started) app.ticker.stop();
      if (PIXI.Ticker && PIXI.Ticker.shared && PIXI.Ticker.shared.started) PIXI.Ticker.shared.stop();
    } else {
      if (app && app.ticker && !app.ticker.started) app.ticker.start();
      if (PIXI.Ticker && PIXI.Ticker.shared && !PIXI.Ticker.shared.started) PIXI.Ticker.shared.start();
    }
  }

  // Expose to window.Live2DBridge
  window.Live2DBridge = {
    setMouthOpen,
    triggerMotion,
    triggerMotionByTag,
    onChunkStart,
    onPlaybackComplete,
    onInterrupt,
    settleToIdle,
    setExpression,
    setPaused,
    setFPSMode: applyFPSMode,
    switchOutfit,
    setIntimacyScore: (score) => { if (window.__setIntimacyScore) window.__setIntimacyScore(score); },
    layoutModel,
    getCurrentOutfit: () => currentOutfit,
    isReady: () => !!live2dModel,
    getActiveFPS: () => app.ticker.maxFPS,
  };
})();
