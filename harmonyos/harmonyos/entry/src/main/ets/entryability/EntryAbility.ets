import { AbilityConstant, ConfigurationConstant, UIAbility, Want, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DistributedService } from '../service/DistributedService';

const DOMAIN = 0x0000;
// 拍照/选图走 cameraPicker 与 PhotoViewPicker（免权限安全控件），无需相机与媒体库权限
const PERMISSIONS: Permissions[] = [
  'ohos.permission.DISTRIBUTED_DATASYNC',
];

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to set colorMode. Cause: ' + String(err));
    }
    // 应用启动时初始化分布式数据管理（fire-and-forget，不阻塞启动）
    DistributedService.init(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'EntryAbility', 'DistributedService.init failed: ' + err.message);
    });
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onWindowStageCreate');

    this.requestPermissions();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'EntryAbility', 'Failed to load the content. Cause: ' + String(err));
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onBackground');
  }

  private requestPermissions(): void {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(this.context, PERMISSIONS)
        .then((result) => {
          hilog.info(DOMAIN, 'EntryAbility', 'requestPermissions result: ' + result.authResults.toString());
        })
        .catch((err: Error) => {
          hilog.error(DOMAIN, 'EntryAbility', 'requestPermissions failed: ' + err.message);
        });
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'requestPermissions exception: ' + String(err));
    }
  }
}
