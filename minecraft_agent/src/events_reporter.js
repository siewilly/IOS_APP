// events_reporter.js - 即時向 Open-LLM-VTuber 後端推送 Minecraft 遊戲事件

class EventsReporter {
  constructor(backendUrl = 'http://127.0.0.1:12393') {
    this.backendUrl = backendUrl.replace(/\/+$/, '');
    this._statusTimer = null;
  }

  async sendEvent(payload) {
    try {
      const resp = await fetch(`${this.backendUrl}/api/minecraft/event`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          timestamp: Date.now(),
          ...payload
        })
      });
      return resp.ok;
    } catch (e) {
      // 後端若未啟動則靜默忽略，避免中斷 Bot
      return false;
    }
  }

  startStatusPolling(bot, intervalMs = 3000) {
    if (this._statusTimer) clearInterval(this._statusTimer);

    this._statusTimer = setInterval(() => {
      if (!bot || !bot.entity) return;

      const pos = bot.entity.position;
      let biomeName = 'unknown';
      try {
        const block = bot.blockAt(pos);
        if (block && block.biome) {
          biomeName = block.biome.name || String(block.biome);
        }
      } catch (e) {}

      this.sendEvent({
        event: 'telemetry',
        data: {
          connected: true,
          username: bot.username,
          hp: Number((bot.health || 0).toFixed(1)),
          maxHp: 20,
          food: Number((bot.food || 0).toFixed(1)),
          position: {
            x: Number(pos.x.toFixed(1)),
            y: Number(pos.y.toFixed(1)),
            z: Number(pos.z.toFixed(1))
          },
          biome: biomeName,
          timeOfDay: bot.time ? bot.time.timeOfDay : 0,
          isRaining: Boolean(bot.isRaining)
        }
      });
    }, intervalMs);
  }

  stopStatusPolling() {
    if (this._statusTimer) {
      clearInterval(this._statusTimer);
      this._statusTimer = null;
    }
  }
}

module.exports = { EventsReporter };
