const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

function sh(cmd, desc) {
  try {
    const out = execSync(`"${hdc}" shell "${cmd}"`, { timeout: 10000 });
    console.log(`--- ${desc} ---`);
    console.log(out.toString());
    return out.toString();
  } catch(e) {
    console.log(`--- ${desc} --- FAILED`);
    console.log(e.message.substring(0, 200));
    return '';
  }
}

// Try various ways to trigger media scan
// Method 1: aa broadcast
sh('aa broadcast -a ohos.intent.action.MEDIA_SCANNER_SCAN_FILE --p bundleName com.titaifenxi.app 2>/dev/null || echo no', '1. Media scan broadcast');

// Method 2: Check if there's a mediaserver or media_provider
sh('ps -ef | grep -i media 2>/dev/null | head -10', '2. Media processes');

// Method 3: Try sending a broadcast with data parameter
sh('aa broadcast -a ohos.intent.action.MEDIA_SCANNER_SCAN_FILE -p com.android.providers.media 2>/dev/null || echo no', '3. Media provider scan');

// Method 4: Restart media service
sh('aa start -a ohos.app.MediaServiceAbility 2>/dev/null || echo no', '4. Start media service');

// Method 5: Check if there's a media library utility
sh('ls /system/bin/ | grep -i media 2>/dev/null', '5. Media binaries');

// Method 6: Use the app's own media scanning via ContentHelper
sh('aa start -a AbilityForm -b com.titaifenxi.app 2>/dev/null || echo no', '6. Start app ability');

// Method 7: Trigger via bm
sh('bm dump -p com.titaifenxi.app 2>&1 | head -20', '7. App bundle info');

// Method 8: Try to copy files to another location that may trigger auto-scan
sh('cp /storage/media/100/local/files/Pictures/front.jpg /storage/media/100/local/files/DCIM/ 2>&1 || echo cp_fail', '8. Copy test');

// Check if files exist
sh('ls -la /storage/media/100/local/files/Pictures/', '9. Verify pictures');
sh('ls -la /storage/media/100/local/files/DCIM/', '10. Verify DCIM');
