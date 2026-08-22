const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 5000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString());
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- FAILED`);
    console.log(e.message.slice(0, 200));
    return '';
  }
}

// 探索各种可能的相册路径
sh('ls -la /storage/media/', '1. /storage/media/');
sh('ls -la /storage/', '2. /storage/');
sh('ls -la /data/storage/', '3. /data/storage/');
sh('ls -la /mnt/harmony/', '4. /mnt/harmony/');
sh('ls -la /mnt/', '5. /mnt/');

// Find media-related directories
sh('find /storage -type d -name "Pictures" 2>/dev/null || echo "no find"', '6. find Pictures');
sh('find /storage -type d -name "DCIM" 2>/dev/null || echo "no find"', '7. find DCIM');
sh('find /data -type d -name "Pictures" 2>/dev/null || echo "no find"', '8. find Pictures in data');

// Check what's in the directory user dropped files to
sh('ls -la /storage/media/100/local/files/', '9. user file location');
sh('ls -la /storage/media/100/', '10. 100/');
