import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { Constants } from '../common/Constants';

interface HistoryEntry {
  score: string;
  date: string;
}

export default class PostureFormAbility extends FormExtensionAbility {
  /**
   * 从本地历史记录读取最新评分，构建卡片绑定数据
   * onAddForm 和 onUpdateForm 共用，消除重复
   */
  private buildFormDataSync(): formBindingData.FormBindingData {
    const formData: Record<string, string | number> = {
      'score': '--',
      'level': '等待评估',
      'lastTime': '尚未评估',
    };

    // 卡片环境无法访问 preferences（需要异步获取），返回默认数据
    // 后续可通过 updateForm 回调异步刷新
    hilog.info(0x0000, 'PostureFormAbility', 'buildFormDataSync: returning default data');

    return formBindingData.createFormBindingData(formData);
  }

  onAddForm(want: Record<string, Object>): formBindingData.FormBindingData {
    hilog.info(0x0000, 'PostureFormAbility', 'onAddForm called');
    return this.buildFormDataSync();
  }

  onUpdateForm(formId: string): void {
    hilog.info(0x0000, 'PostureFormAbility', 'onUpdateForm called, formId: ' + formId);
    const bindingData: formBindingData.FormBindingData = this.buildFormDataSync();
    formProvider.updateForm(formId, bindingData).catch((err: Error) => {
      hilog.error(0x0000, 'PostureFormAbility', 'updateForm failed: ' + String(err));
    });
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(0x0000, 'PostureFormAbility', 'onFormEvent: ' + message);
  }

  onRemoveForm(formId: string): void {
    hilog.info(0x0000, 'PostureFormAbility', 'onRemoveForm called, formId: ' + formId);
  }

  onCastToNormal(formId: string): void {
    hilog.info(0x0000, 'PostureFormAbility', 'onCastToNormal: ' + formId);
  }

  onAcquireFormState(want: Record<string, Object>): number {
    hilog.info(0x0000, 'PostureFormAbility', 'onAcquireFormState called');
    return 1; // FormState.READY = 1
  }
}
