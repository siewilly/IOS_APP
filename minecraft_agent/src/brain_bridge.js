// brain_bridge.js - 與 Open-LLM-VTuber 後端大腦與角色記憶對接

class BrainBridge {
  constructor(bot, botController, backendUrl = 'http://127.0.0.1:12393') {
    this.bot = bot;
    this.controller = botController;
    this.backendUrl = backendUrl.replace(/\/+$/, '');
  }

  async processPlayerChat(username, message) {
    if (username === this.bot.username) return;

    // 取得當前遊戲世界上下文
    const pos = this.bot.entity?.position;
    let biome = 'plains';
    try {
      const b = this.bot.blockAt(pos);
      if (b && b.biome) biome = b.biome.name || String(b.biome);
    } catch (e) {}

    const worldContext = {
      sender: username,
      hp: Number((this.bot.health || 20).toFixed(1)),
      food: Number((this.bot.food || 20).toFixed(1)),
      biome,
      timeOfDay: this.bot.time ? this.bot.time.timeOfDay : 0,
      isRaining: Boolean(this.bot.isRaining),
      isFighting: Boolean(this.controller.combat?.isFighting),
      isFollowing: Boolean(this.controller.follow?.isFollowing)
    };

    try {
      const resp = await fetch(`${this.backendUrl}/api/minecraft/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: username,
          text: message,
          context: worldContext
        })
      });

      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}`);
      }

      const data = await resp.json();
      const replyText = data.reply || '';
      const actions = data.actions || [];

      // 執行解析出的遊戲指令
      this.executeActions(actions, username);

      // 清理標籤並發送到遊戲聊天室
      const cleanReply = replyText
        .replace(/\[(?:mc:[^\]]+|motion:[^\]]+|bgm:[^\]]+|[a-zA-Z0-9_:-]+)\]/gi, '')
        .trim();

      if (cleanReply) {
        // Minecraft 聊天室單行長度防爆 (過長自動分段)
        this.sendChunkedChat(cleanReply);
      }

      return { reply: cleanReply, actions };
    } catch (err) {
      // 若後端大腦離線，啟動本機規則備援回應
      return this.fallbackRuleResponse(username, message);
    }
  }

  executeActions(actions, senderName) {
    for (const act of actions) {
      if (act === 'follow' || act === 'mc:follow') {
        this.controller.follow?.start(senderName);
      } else if (act === 'stop' || act === 'mc:stop') {
        this.controller.follow?.stop();
        this.controller.combat?.stop();
        this.controller.actions?.stopDance();
      } else if (act === 'dance' || act === 'mc:dance') {
        this.controller.actions?.startDance(12);
      } else if (act === 'sleep' || act === 'mc:sleep') {
        this.controller.actions?.sleepInNearbyBed();
      }
    }
  }

  sendChunkedChat(message) {
    const maxLen = 95;
    if (message.length <= maxLen) {
      this.bot.chat(message);
      return;
    }

    const chunks = [];
    for (let i = 0; i < message.length; i += maxLen) {
      chunks.push(message.slice(i, i + maxLen));
    }

    chunks.forEach((chunk, idx) => {
      setTimeout(() => {
        try {
          this.bot.chat(chunk);
        } catch (e) {}
      }, idx * 600);
    });
  }

  fallbackRuleResponse(username, message) {
    const msg = message.toLowerCase();
    let reply = '';

    if (msg.includes('跟') || msg.includes('來') || msg.includes('follow') || msg.includes('come')) {
      const res = this.controller.follow?.start(username);
      reply = res.message;
    } else if (msg.includes('停') || msg.includes('別動') || msg.includes('stop') || msg.includes('wait')) {
      const res = this.controller.follow?.stop();
      reply = res.message;
    } else if (msg.includes('跳舞') || msg.includes('dance') || msg.includes('搖擺')) {
      this.controller.actions?.startDance(10);
      reply = '哇～好呀！那我也跟著節奏一起跳舞囉！💃';
    } else if (msg.includes('睡覺') || msg.includes('sleep') || msg.includes('晚安')) {
      this.controller.actions?.sleepInNearbyBed().then(r => this.bot.chat(r.message));
      return;
    } else {
      reply = `嗯！我聽到了喔，${username}！雖然現在魔力訊號有點弱，但我會一直在你身邊的！🌸`;
    }

    if (reply) {
      this.sendChunkedChat(reply);
    }
    return { reply, actions: [] };
  }
}

module.exports = { BrainBridge };
