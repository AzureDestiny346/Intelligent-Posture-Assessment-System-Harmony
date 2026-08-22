const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

try {
  // Test health endpoint from emulator
  const out = execSync(`"${hdc}" shell "curl -s http://10.0.2.2:5000/health"`, { timeout: 10000 });
  console.log('Health response:', out.toString());
} catch (e) {
  console.error('Error:', e.message);
  // Try wget
  try {
    const out2 = execSync(`"${hdc}" shell "wget -q -O - http://10.0.2.2:5000/health 2>/dev/null"`, { timeout: 10000 });
    console.log('Health via wget:', out2.toString());
  } catch (e2) {
    console.error('wget also failed:', e2.message);
  }
}
