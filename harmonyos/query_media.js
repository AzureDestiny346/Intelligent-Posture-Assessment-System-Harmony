const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 10000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString().substring(0, 800));
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- ERR: ${e.message.substring(0, 150)}`);
    return '';
  }
}

// Check media library directories
sh('mediatool ls -l /', '1. Root media dirs');
sh('mediatool ls -l /local', '2. /local');
sh('mediatool ls -l /local/files', '3. /local/files');
sh('mediatool ls -l /local/files/Pictures', '4. Pictures');
sh('mediatool ls -l /local/files/DCIM', '5. DCIM');

// Query our files
sh('mediatool query front.jpg', '6. query front.jpg');
sh('mediatool query side.png', '7. query side.png');
sh('mediatool query back.png', '8. query back.png');
