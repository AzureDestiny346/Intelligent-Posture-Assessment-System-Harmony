const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

try {
  console.log('启动 App...');
  execSync(`"${hdc}" shell aa start -a EntryAbility -b com.titaifenxi.app`, { stdio: 'inherit', timeout: 15000 });
  console.log('App 启动成功');
} catch (e) {
  console.error('错误:', e.message);
}
