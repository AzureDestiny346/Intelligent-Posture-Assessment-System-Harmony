const { execSync } = require('child_process');
const path = require('path');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

// 照片源路径
const photos = [
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_2026-05-28_103240_854.png', name: 'front.jpg' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260524232438_1206_10.png', name: 'side.png' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260524232443_1207_10.png', name: 'back.png' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260528103924_1339_10.jpg', name: 'front_real.jpg' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260528103925_1340_10.jpg', name: 'side_real.jpg' },
  { src: 'D:\\Desktop\\Project\\工程文件\\titaifenxi\\微信图片_20260528103926_1341_10.jpg', name: 'back_real.jpg' },
];

// 模拟器目标路径（HarmonyOS 相册目录）
const remoteDir = '/data/storage/el2/base/mediaphoto/Pictures';

try {
  // 先创建目标目录
  console.log('创建目录...');
  execSync(`"${hdc}" shell mkdir -p ${remoteDir}`, { stdio: 'inherit' });

  // 推送每张照片
  for (const photo of photos) {
    console.log(`推送: ${photo.src} -> ${remoteDir}/${photo.name}`);
    execSync(`"${hdc}" file send "${photo.src}" ${remoteDir}/${photo.name}`, { stdio: 'inherit', timeout: 30000 });
    console.log(`✓ ${photo.name} 完成`);
  }

  // 刷新媒体库
  console.log('刷新媒体库...');
  execSync(`"${hdc}" shell aa broadcast -a ohos.intent.action.MEDIA_SCANNER_SCAN_FILE -p com.android.providers.media`, { stdio: 'inherit', timeout: 10000 });

  console.log('\n全部照片已推送到模拟器相册！');
} catch (e) {
  console.error('错误:', e.message);
}
