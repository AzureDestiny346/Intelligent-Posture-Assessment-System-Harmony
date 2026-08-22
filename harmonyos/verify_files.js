const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 10000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString());
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- ERR: ${e.message.substring(0, 150)}`);
    return '';
  }
}

// Use hdc file recv to list what's on the device in the picture directories
// Actually, file recv checks if a specific file exists by trying to pull it

const hdc2 = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function verifyFile(remotePath, name) {
  try {
    execSync(`"${hdc2}" file recv ${remotePath}${name} NUL`, { timeout: 5000 });
    console.log(`✅ ${remotePath}${name} exists`);
    return true;
  } catch(e) {
    console.log(`❌ ${remotePath}${name} NOT found`);
    return false;
  }
}

const paths = ['/storage/media/100/local/files/Pictures/', '/storage/media/100/local/files/DCIM/', '/data/local/tmp/'];
const names = ['front.jpg', 'side.png', 'back.png', 'front_real.jpg', 'side_real.jpg', 'back_real.jpg'];

for (const p of paths) {
  console.log(`\n=== ${p} ===`);
  for (const n of names) {
    verifyFile(p, n);
  }
}

// Also check what directories the shell can list
sh('ls -la /data/local/tmp/', 'tmp listing');
