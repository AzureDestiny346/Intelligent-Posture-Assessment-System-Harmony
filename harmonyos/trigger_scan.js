const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 10000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString().substring(0, 500));
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- ERR: ${e.message.substring(0, 100)}`);
    return '';
  }
}

// mediatool is available - try its help
sh('mediatool', '1. mediatool help');

// Also try restarting media service (might trigger rescan)
sh('aa force-stop com.ohos.medialibrary.medialibrarydata 2>&1 || echo no', '2. force stop medialibrary');

// Wait and check if it restarts automatically
// (System services usually auto-restart)
