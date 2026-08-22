const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 10000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString().substring(0, 600));
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} ---`);
    console.log(e.message.substring(0, 200));
    return '';
  }
}

// 1. Check media processes before
sh('ps -ef | grep medialibrary', '1. Before restart');

// 2. Kill the media library data process to force restart
sh('aa force-stop com.ohos.medialibrary.medialibrarydata 2>&1 || echo fail', '2. Stop medialibrary');

// 3. Wait and check if it restarted
sh('sleep 3', '3. Wait');
sh('ps -ef | grep medialibrary', '4. After restart');

// 4. Try restarting media_service too
sh('aa force-stop media_service 2>&1 || echo fail', '5. Stop media_service');
sh('sleep 3', '6. Wait');
sh('ps -ef | grep -E "media_service|medialibrary"', '7. Services');

// 5. Query our files again
sh('mediatool query front.jpg', '8. Query files');
sh('mediatool query side.png', '9. Query side');
