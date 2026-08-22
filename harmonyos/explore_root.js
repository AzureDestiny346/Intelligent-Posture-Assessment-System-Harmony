const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 8000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString().substring(0, 1200));
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- FAILED`);
    console.log(e.message.slice(0, 200));
    return '';
  }
}

// Try su
sh('su root ls /storage/media/ 2>/dev/null || echo no_root', '1. su root');
sh('su 0 ls /storage/media/ 2>/dev/null || echo no_su0', '2. su 0');

// Check uid and groups
sh('id', '3. current user');
sh('whoami', '4. whoami');

// Check if we can use the hdc as root user
sh('groups', '5. groups');

// Try the App account - find our app's uid
sh('ps -ef | grep -i titaifenxi 2>/dev/null || echo no_app_process', '6. app process');

// Check data/local/tmp - we KNOW we can write here
sh('ls -la /data/local/tmp/', '7. local tmp');

// Also check what happened when user dragged files - maybe in /tmp?
sh('ls -la /tmp/ 2>/dev/null || echo no_tmp', '8. tmp');
sh('ls -la /data/local/ 2>/dev/null || echo no_local_data', '9. data local');

// Check /sdcard symlink
sh('ls -la /sdcard 2>/dev/null || echo no_sdcard', '10. sdcard');

// Check HarmonyOS specific internal storage paths
sh('ls -la /data/app/ 2>/dev/null || echo no_app_data', '11. app data root');
