// actions.js - 動作、跳舞、禮物與睡眠互動模組

class ActionsBehavior {
  constructor(bot) {
    this.bot = bot;
    this.isDancing = false;
    this._danceTimer = null;
  }

  startDance(durationSec = 10) {
    if (this.isDancing) return;
    this.isDancing = true;

    let step = 0;
    const interval = 280; // ms
    const maxSteps = Math.floor((durationSec * 1000) / interval);

    this._danceTimer = setInterval(() => {
      step++;
      if (step > maxSteps || !this.isDancing) {
        this.stopDance();
        return;
      }

      // 踩點節奏：下蹲、起立、跳躍、轉向微擺
      const mod = step % 4;
      if (mod === 0) {
        this.bot.setControlState('sneak', true);
      } else if (mod === 1) {
        this.bot.setControlState('sneak', false);
      } else if (mod === 2) {
        this.bot.setControlState('jump', true);
        setTimeout(() => this.bot.setControlState('jump', false), 150);
      } else if (mod === 3) {
        this.bot.setControlState('sneak', false);
      }
    }, interval);
  }

  stopDance() {
    this.isDancing = false;
    if (this._danceTimer) {
      clearInterval(this._danceTimer);
      this._danceTimer = null;
    }
    this.bot.setControlState('sneak', false);
    this.bot.setControlState('jump', false);
  }

  async sleepInNearbyBed() {
    const master = this.bot?.masterPlayer || '有栖';
    const bed = this.bot.findBlock({
      matching: block => block.name.includes('bed'),
      maxDistance: 4
    });

    if (!bed) {
      return { success: false, message: `附近沒有床呢…${master}我們一起找個安全的地方吧！` };
    }

    try {
      await this.bot.sleep(bed);
      return { success: true, message: `呼…${master}晚安，明天見喔…🌙` };
    } catch (err) {
      return { success: false, message: `無法入睡：${err.message}` };
    }
  }

  async tossItemToPlayer(itemName, count = 1, targetPlayer = null) {
    const target = targetPlayer || this.bot.nearestEntity(e => e.type === 'player');
    if (target) {
      await this.bot.lookAt(target.position.offset(0, 1.6, 0), true);
    }

    const item = this.bot.inventory.items().find(i => i.name.toLowerCase().includes(itemName.toLowerCase()));
    if (!item) {
      return { success: false, message: `我的包包裡好像沒有 ${itemName} 耶…` };
    }

    try {
      await this.bot.toss(item.type, null, Math.min(count, item.count));
      return { success: true, message: `給你 ${item.displayName || itemName}！收好喔～` };
    } catch (err) {
      return { success: false, message: `丟出物品失敗：${err.message}` };
    }
  }
}

module.exports = { ActionsBehavior };
