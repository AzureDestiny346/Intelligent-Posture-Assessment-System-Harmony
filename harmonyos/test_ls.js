const { execSync } = require('child_process');
const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

try {
  const out = execSync(`"${hdc}" shell "ls /system/bin/ | head -50"`, { timeout: 5000 });
  console.log(out.toString());
} catch(e) {
  console.error(e.message);
}
