// follow.js - 自動尋路跟隨主人行為模組
const { goals } = require('mineflayer-pathfinder');

class FollowBehavior {
  constructor(bot, config = {}) {
    this.bot = bot;
    this.config = config;
    this.isFollowing = false;
    this.targetPlayer = null;
    this.distance = config.followDistance || 2.5;
  }

  start(playerName) {
    const target = playerName
      ? this.bot.players[playerName]?.entity
      : this.getNearestPlayer();

    if (!target) {
      return { success: false, message: '找不到附近的冒險者呀，你在哪裡呢？' };
    }

    this.targetPlayer = target;
    this.isFollowing = true;

    try {
      const goal = new goals.GoalFollow(target, this.distance);
      this.bot.pathfinder.setGoal(goal, true);
      return {
        success: true,
        message: `うん！我會緊緊跟在${target.username || '你'}身後的！`,
        targetName: target.username
      };
    } catch (err) {
      return { success: false, message: `尋路失敗：${err.message}` };
    }
  }

  stop() {
    this.isFollowing = false;
    this.targetPlayer = null;
    try {
      this.bot.pathfinder.setGoal(null);
      return { success: true, message: '好～那我就先停在這裡等你喔！' };
    } catch (err) {
      return { success: false, message: err.message };
    }
  }

  getNearestPlayer() {
    let nearest = null;
    let minDistance = Infinity;

    for (const name in this.bot.players) {
      const p = this.bot.players[name];
      if (p.username === this.bot.username || !p.entity) continue;
      const d = this.bot.entity.position.distanceTo(p.entity.position);
      if (d < minDistance) {
        minDistance = d;
        nearest = p.entity;
      }
    }
    return nearest;
  }
}

module.exports = { FollowBehavior };
