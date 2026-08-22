const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd) {
  try {
    const out = execSync(`"${hdc}" ${cmd}`, { timeout: 10000 });
    console.log(out.toString());
  } catch (e) {
    console.log('ERR:', e.message.substring(0, 200));
  }
}

console.log('=== HDC target devices ===');
sh('list targets');

console.log('=== HDC start server ===');
sh('start -r');

console.log('=== After restart ===');
sh('list targets');
