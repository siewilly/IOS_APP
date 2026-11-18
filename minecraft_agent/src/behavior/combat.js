// combat.js - 愛蜜莉雅微精靈守護與戰鬥模組

class CombatBehavior {
  constructor(bot, config = {}) {
    this.bot = bot;
    this.config = config;
    this.isFighting = false;
    this.currentTarget = null;
  }

  equipBestWeapon() {
    const sword = this.bot.inventory.items().find(i => i.name.includes('sword'));
    const axe = this.bot.inventory.items().find(i => i.name.includes('axe'));
    const weapon = sword || axe;

    if (weapon) {
      this.bot.equip(weapon, 'hand').catch(() => {});
    }

    const shield = this.bot.inventory.items().find(i => i.name.includes('shield'));
    if (shield) {
      this.bot.equip(shield, 'off-hand').catch(() => {});
    }
  }

  attack(target) {
    if (!target || !target.isValid) return;
    this.isFighting = true;
    this.currentTarget = target;
    this.equipBestWeapon();

    if (this.bot.pvp) {
      this.bot.pvp.attack(target);
    }
  }

  stop() {
    this.isFighting = false;
    this.currentTarget = null;
    if (this.bot.pvp) {
      this.bot.pvp.stop();
    }
  }

  findNearbyThreat(radius = 8) {
    const hostileTypes = [
      'zombie', 'skeleton', 'spider', 'creeper', 'drowned',
      'husk', 'stray', 'cave_spider', 'enderman', 'witch'
    ];

    return this.bot.nearestEntity(e => {
      if (!e || e.type !== 'mob') return false;
      const d = this.bot.entity.position.distanceTo(e.position);
      if (d > radius) return false;
      return hostileTypes.some(ht => e.name?.toLowerCase().includes(ht));
    });
  }
}

module.exports = { CombatBehavior };
