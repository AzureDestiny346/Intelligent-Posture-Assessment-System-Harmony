const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 5000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString().substring(0, 1000));
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- FAILED`);
    console.log(e.message.slice(0, 200));
    return '';
  }
}

// Explore accessible paths
sh('ls -la /mnt/sandbox/', '1. /mnt/sandbox/');
sh('ls -la /mnt/hmdfs/', '2. /mnt/hmdfs/');
sh('ls -la /mnt/data/', '3. /mnt/data/');

// Try sandbox paths for common users
sh('ls -la /mnt/sandbox/100/', '4. sandbox/100/');
sh('ls -la /mnt/sandbox/100/*/files/ 2>/dev/null', '5. sandbox apps files');

// Check hmdfs - this is often the media storage on HarmonyOS
sh('ls -la /mnt/hmdfs/100/', '6. hmdfs/100/');
sh('ls -la /mnt/hmdfs/100/*/ 2>/dev/null', '7. hmdfs subpaths');

// Check if there's a data mirror
sh('ls -la /mnt/data/100/', '8. /mnt/data/100/');

// Check accessible directories recursively limited depth
sh('ls -d /mnt/hmdfs/*/*/*/Pictures 2>/dev/null || echo no', '9. hmdfs Pictures');
sh('ls -d /mnt/sandbox/*/*/*/Pictures 2>/dev/null || echo no', '10. sandbox Pictures');

// Maybe the user dropped files to a specific location - check what app can access
sh('ls -laR /mnt/hmdfs/ 2>/dev/null | head -50', '11. hmdfs recursive');
