// emilia_bot.js - 愛蜜莉雅 Mineflayer 機器人主核心

const mineflayer = require('mineflayer');
const { pathfinder, Movements } = require('mineflayer-pathfinder');
const pvp = require('mineflayer-pvp').plugin;
const autoEat = require('mineflayer-auto-eat').loader;

const { FollowBehavior } = require('./behavior/follow');
const { CombatBehavior } = require('./behavior/combat');
const { ActionsBehavior } = require('./behavior/actions');
const { EventsReporter } = require('./events_reporter');
const { BrainBridge } = require('./brain_bridge');

class EmiliaBot {
  constructor(config = {}) {
    this.config = {
      host: config.host || 'localhost',
      port: config.port ? parseInt(config.port, 10) : 25565,
      username: config.username || 'Emilia',
      auth: config.auth || 'offline',
      version: config.version || false,
      backendUrl: config.backendUrl || 'http://127.0.0.1:12393',
      autoReconnect: config.autoReconnect !== false,
      reconnectIntervalMs: config.reconnectIntervalMs || 5000,
      autoDefend: config.autoDefend !== false,
      ...config
    };

    this.bot = null;
    this.isConnected = false;
    this.isSpawned = false;
    this.reconnectTimer = null;
    this.lastHealth = 20;

    // Submodules
    this.reporter = new EventsReporter(this.config.backendUrl);
    this.follow = null;
    this.combat = null;
    this.actions = null;
    this.brain = null;
  }

  start() {
    if (this.bot) {
      console.log('[EmiliaBot] Bot is already running or connecting');
      return;
    }

    console.log(`[EmiliaBot] Connecting to Minecraft server ${this.config.host}:${this.config.port} as ${this.config.username}...`);

    const botOptions = {
      host: this.config.host,
      port: this.config.port,
      username: this.config.username,
      auth: this.config.auth,
      hideErrors: false
    };

    if (this.config.version) {
      botOptions.version = this.config.version;
    }

    try {
      this.bot = mineflayer.createBot(botOptions);
      this._bindPlugins();
      this._bindEvents();
    } catch (err) {
      console.error('[EmiliaBot] Creation error:', err.message);
      this._scheduleReconnect();
    }
  }

  stop() {
    this.config.autoReconnect = false;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.reporter.stopStatusPolling();

    if (this.bot) {
      try {
        const master = this.config.masterPlayer || '有栖';
        this.bot.quit(`再見囉，${master}！我先回現實世界等你～🌸`);
      } catch (e) {}
      this.bot = null;
    }

    this.isConnected = false;
    this.isSpawned = false;
    console.log('[EmiliaBot] Bot stopped.');
  }

  _bindPlugins() {
    try {
      this.bot.loadPlugin(pathfinder);
    } catch (e) {
      console.warn('[EmiliaBot] Pathfinder plugin load error:', e.message);
    }
    try {
      this.bot.loadPlugin(pvp);
    } catch (e) {
      console.warn('[EmiliaBot] PvP plugin load error:', e.message);
    }
    try {
      this.bot.loadPlugin(autoEat);
    } catch (e) {
      console.warn('[EmiliaBot] AutoEat plugin load error:', e.message);
    }

    this.bot.masterPlayer = this.config.masterPlayer || '有栖';
    this.follow = new FollowBehavior(this.bot, this.config);
    this.combat = new CombatBehavior(this.bot, this.config);
    this.actions = new ActionsBehavior(this.bot);
    this.brain = new BrainBridge(this.bot, this, this.config.backendUrl);
  }

  _bindEvents() {
    this.bot.once('login', () => {
      this.isConnected = true;
      console.log(`[EmiliaBot] Logged into server as ${this.bot.username}`);
      this.reporter.sendEvent({
        event: 'connected',
        data: { username: this.bot.username, host: this.config.host, port: this.config.port }
      });
    });

    this.bot.once('spawn', () => {
      this.isSpawned = true;
      console.log('[EmiliaBot] Spawned in world! Configuring movements & auto-eat...');

      // 初始化 Pathfinding 物理移動設定
      const defaultMove = new Movements(this.bot);
      defaultMove.canDig = true;
      defaultMove.allow1by1towers = false;
      defaultMove.scaffoldingBlocks = [];
      this.bot.pathfinder.setMovements(defaultMove);

      // 自動進食設定 (血量或飽食度過低自動吃食物)
      if (this.bot.autoEat) {
        this.bot.autoEat.options = {
          priority: 'foodPoints',
          startAt: 14,
          bannedFood: ['rotten_flesh', 'poisonous_potato', 'pufferfish', 'spider_eye']
        };
      }

      this.lastHealth = this.bot.health || 20;
      this.reporter.startStatusPolling(this.bot, 3000);

      // 自動套用愛蜜莉雅專屬皮膚 (FabricTailor / SkinsRestorer)
      setTimeout(() => {
        try {
          const skinUrl = 'https://files.catbox.moe/8fpx2h.png';
          this.bot.chat(`/skin set ${skinUrl}`);
          console.log(`[EmiliaBot] Set skin via: /skin set ${skinUrl}`);
        } catch (e) {}
      }, 800);

      // 進服問候語
      setTimeout(() => {
        try {
          const master = this.config.masterPlayer || '有栖';
          this.bot.chat(`${master}、準備好了嗎？愛蜜莉雅參上！今天也一起在異世界努力吧！🌸`);
        } catch (e) {}
      }, 1500);
    });

    // 玩家聊天室監聽
    this.bot.on('chat', (username, message) => {
      if (username === this.bot.username) return;
      console.log(`[MC-Chat] <${username}> ${message}`);
      if (this.brain) this.brain.processPlayerChat(username, message);
    });

    this.bot.on('whisper', (username, message) => {
      if (username === this.bot.username) return;
      console.log(`[MC-Whisper] <${username}> ${message}`);
      if (this.brain) this.brain.processPlayerChat(username, message);
    });

    // 備援監聽 messagestr（處理 Paper/Fabric 伺服器自定義 chat 格式）
    this.bot.on('messagestr', (message) => {
      if (!message || message.startsWith(`[Emilia]`) || message.includes('愛蜜莉雅')) return;
      const match = message.match(/^(?:\[Not Secure\]\s*)?<([a-zA-Z0-9_]+)>\s*(.+)$/);
      if (match) {
        const [, sender, text] = match;
        if (sender !== this.bot.username && this.brain) {
          console.log(`[MC-MessageStr] Captured chat: <${sender}> ${text}`);
          this.brain.processPlayerChat(sender, text);
        }
      }
    });

    // 受傷監聽 (觸發桌寵痛痛哭哭微表情)
    this.bot.on('health', () => {
      const currentHp = this.bot.health;
      if (currentHp < this.lastHealth) {
        const damage = this.lastHealth - currentHp;
        console.log(`[EmiliaBot] Damaged! HP: ${currentHp.toFixed(1)}/20 (Lost ${damage.toFixed(1)})`);
        this.reporter.sendEvent({
          event: 'damaged',
          data: {
            hp: Number(currentHp.toFixed(1)),
            maxHp: 20,
            damage: Number(damage.toFixed(1))
          }
        });
      }
      this.lastHealth = currentHp;
    });

    // 玩家投擲禮物監聽 (花朵、鑽石、食物拾取)
    this.bot.on('playerCollect', (collector, collected) => {
      if (!collector || collector.username !== this.bot.username) return;

      try {
        const itemObj = collected.metadata?.[8] || collected.metadata?.[7];
        const itemId = itemObj?.itemId;
        let itemName = 'item';
        if (itemId && this.bot.registry.items[itemId]) {
          itemName = this.bot.registry.items[itemId].name;
        }

        console.log(`[EmiliaBot] Collected item: ${itemName}`);
        this.reporter.sendEvent({
          event: 'gift',
          data: {
            item: itemName,
            timestamp: Date.now()
          }
        });
      } catch (e) {}
    });

    // 自主防衛與反擊
    this.bot.on('entityHurt', (entity) => {
      if (!this.config.autoDefend) return;
      if (entity === this.bot.entity) {
        const threat = this.combat?.findNearbyThreat(7);
        if (threat) {
          console.log(`[EmiliaBot] Auto-defending against ${threat.name}`);
          this.combat.attack(threat);
        }
      }
    });

    // 斷線與踢出處理
    this.bot.on('kicked', (reason) => {
      console.warn('[EmiliaBot] Kicked from server:', reason);
      this._handleDisconnect();
    });

    this.bot.on('end', () => {
      console.log('[EmiliaBot] Connection ended.');
      this._handleDisconnect();
    });

    this.bot.on('error', (err) => {
      console.error('[EmiliaBot] Socket error:', err.message);
      this._handleDisconnect();
    });
  }

  _handleDisconnect() {
    this.isConnected = false;
    this.isSpawned = false;
    this.reporter.stopStatusPolling();
    this.reporter.sendEvent({
      event: 'disconnected',
      data: { username: this.config.username }
    });
    this.bot = null;
    this._scheduleReconnect();
  }

  _scheduleReconnect() {
    if (!this.config.autoReconnect) return;
    if (this.reconnectTimer) return;

    console.log(`[EmiliaBot] Will attempt reconnect in ${this.config.reconnectIntervalMs / 1000}s...`);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      if (!this.isConnected && this.config.autoReconnect) {
        this.start();
      }
    }, this.config.reconnectIntervalMs);
  }

  getStatus() {
    const pos = this.bot?.entity?.position;
    return {
      connected: this.isConnected,
      spawned: this.isSpawned,
      username: this.config.username,
      host: this.config.host,
      port: this.config.port,
      hp: this.bot ? Number((this.bot.health || 0).toFixed(1)) : 0,
      food: this.bot ? Number((this.bot.food || 0).toFixed(1)) : 0,
      isFollowing: Boolean(this.follow?.isFollowing),
      isFighting: Boolean(this.combat?.isFighting),
      isDancing: Boolean(this.actions?.isDancing),
      position: pos
        ? { x: Number(pos.x.toFixed(1)), y: Number(pos.y.toFixed(1)), z: Number(pos.z.toFixed(1)) }
        : null
    };
  }
}

module.exports = { EmiliaBot };
