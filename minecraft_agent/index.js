// index.js - Minecraft Emilia Agent 入口啟動腳本

const fs = require('fs');
const path = require('path');
const { EmiliaBot } = require('./src/emilia_bot');

const CONFIG_PATH = path.join(__dirname, 'config.json');

function loadConfig() {
  let cfg = {
    host: 'localhost',
    port: 25565,
    username: 'Emilia',
    auth: 'offline',
    backendUrl: 'http://127.0.0.1:12393',
    autoReconnect: true
  };

  if (fs.existsSync(CONFIG_PATH)) {
    try {
      const fileData = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
      cfg = { ...cfg, ...fileData };
    } catch (e) {
      console.warn('[Config] Failed to parse config.json, using defaults.');
    }
  }

  // CLI Arguments override (e.g. node index.js --host=127.0.0.1 --port=25565 --user=Emilia)
  process.argv.slice(2).forEach(arg => {
    if (arg.startsWith('--host=')) cfg.host = arg.split('=')[1];
    if (arg.startsWith('--port=')) cfg.port = parseInt(arg.split('=')[1], 10);
    if (arg.startsWith('--username=') || arg.startsWith('--user=')) cfg.username = arg.split('=')[1];
    if (arg.startsWith('--backend=')) cfg.backendUrl = arg.split('=')[1];
    if (arg.startsWith('--masterPlayer=')) cfg.masterPlayer = arg.split('=')[1];
  });

  return cfg;
}

const config = loadConfig();
console.log('==============================================');
console.log('🌸 愛蜜莉雅 (Emilia) Minecraft 智能同伴機器人');
console.log(`目標伺服器: ${config.host}:${config.port}`);
console.log(`角色名稱:   ${config.username}`);
console.log(`後端大腦:   ${config.backendUrl}`);
console.log('==============================================');

const emilia = new EmiliaBot(config);
emilia.start();

// 優雅退出處理
process.on('SIGINT', () => {
  console.log('\n[Process] Received SIGINT, shutting down EmiliaBot gracefully...');
  emilia.stop();
  setTimeout(() => process.exit(0), 800);
});

process.on('SIGTERM', () => {
  console.log('\n[Process] Received SIGTERM, shutting down...');
  emilia.stop();
  setTimeout(() => process.exit(0), 800);
});
