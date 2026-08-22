const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const photos = [
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_2026-05-28_103240_854.png', name: 'front.jpg' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260524232438_1206_10.png', name: 'side.png' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260524232443_1207_10.png', name: 'back.png' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260528103924_1339_10.jpg', name: 'front_real.jpg' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260528103925_1340_10.jpg', name: 'side_real.jpg' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260528103926_1341_10.jpg', name: 'back_real.jpg' },
];

const targets = [
  // Try various potential album paths
  '/storage/media/100/local/files/Pictures/',
  '/storage/media/100/local/files/DCIM/',
  '/storage/media/100/local/files/Download/',
  '/data/local/tmp/',
];

async function tryPush() {
  // First try each target to see which ones accept writes
  for (const target of targets) {
    try {
      // Try creating the directory
      execSync(`"${hdc}" shell mkdir -p "${target}"`, { timeout: 5000 });
      // Try writing a test file
      execSync(`"${hdc}" shell "echo test > ${target}test.txt"`, { timeout: 5000 });
      const out = execSync(`"${hdc}" shell "cat ${target}test.txt"`, { timeout: 5000 });
      if (out.toString().includes('test')) {
        console.log(`✅ CAN WRITE TO: ${target}`);
        // Clean test
        execSync(`"${hdc}" shell "rm ${target}test.txt"`, { timeout: 5000 });
      } else {
        console.log(`❌ Cannot write: ${target}`);
      }
    } catch(e) {
      console.log(`❌ Cannot access: ${target} - ${e.message.substring(0, 100)}`);
    }
  }
}

tryPush().then(() => {
  // Now try file send to each reachable path
  // file send runs as hdc instead of shell, might have different permissions
  for (const target of targets) {
    for (const photo of photos) {
      try {
        execSync(`"${hdc}" file send "${photo.src}" ${target}${photo.name}`, { timeout: 15000 });
        console.log(`✅ file send OK: ${target}${photo.name}`);
      } catch(e) {
        // ignore errors, just track
      }
    }
  }
  console.log('All done');
});
