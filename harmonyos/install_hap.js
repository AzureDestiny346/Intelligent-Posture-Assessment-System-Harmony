const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const hap = 'D:\\Desktop\\Project\\harmonyos\\harmonyos\\entry\\build\\default\\outputs\\default\\entry-default-signed.hap';

try {
  console.log('安装 HAP...');
  execSync(`"${hdc}" install -r "${hap}"`, { stdio: 'inherit', timeout: 60000 });
  console.log('HAP 安装完成');
} catch (e) {
  console.error('错误:', e.message);
}
