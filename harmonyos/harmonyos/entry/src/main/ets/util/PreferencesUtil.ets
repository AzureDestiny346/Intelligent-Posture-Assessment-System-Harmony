import { preferences } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { HistoryItem, AnalysisResult } from '../model/AnalysisResult';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class PreferencesUtil {
  static async getHistory(context: Context): Promise<HistoryItem[]> {
    try {
      const pref = await preferences.getPreferences(context, Constants.PREF_STORE_NAME);
      const historyStr = pref.getSync(Constants.PREF_HISTORY_KEY, '[]') as string;
      const history: HistoryItem[] = JSON.parse(historyStr);
      return history;
    } catch (err) {
      hilog.error(0x0000, 'PreferencesUtil', 'getHistory failed: ' + String(err));
      return [];
    }
  }

  static async saveHistory(context: Context, score: string, result: AnalysisResult): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, Constants.PREF_STORE_NAME);
      const historyStr = pref.getSync(Constants.PREF_HISTORY_KEY, '[]') as string;
      const history: HistoryItem[] = JSON.parse(historyStr);

      const newItem = new HistoryItem();
      newItem.id = Date.now();
      newItem.date = new Date().toLocaleString();
      newItem.score = score;
      newItem.result = result;

      history.unshift(newItem);

      if (history.length > Constants.MAX_HISTORY_COUNT) {
        history.splice(Constants.MAX_HISTORY_COUNT);
      }

      await pref.put(Constants.PREF_HISTORY_KEY, JSON.stringify(history));
      await pref.flush();

      hilog.info(0x0000, 'PreferencesUtil', 'saveHistory success, count: ' + history.length.toString());
    } catch (err) {
      hilog.error(0x0000, 'PreferencesUtil', 'saveHistory failed: ' + String(err));
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('保存历史记录失败');
    }
  }

  static async deleteHistoryItem(context: Context, id: number): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, Constants.PREF_STORE_NAME);
      const historyStr = pref.getSync(Constants.PREF_HISTORY_KEY, '[]') as string;
      const history: HistoryItem[] = JSON.parse(historyStr);

      const index = history.findIndex(item => item.id === id);
      if (index !== -1) {
        history.splice(index, 1);

        await pref.put(Constants.PREF_HISTORY_KEY, JSON.stringify(history));
        await pref.flush();

        hilog.info(0x0000, 'PreferencesUtil', 'deleteHistoryItem success, id: ' + id.toString());
      }
    } catch (err) {
      hilog.error(0x0000, 'PreferencesUtil', 'deleteHistoryItem failed: ' + String(err));
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('删除历史记录失败');
    }
  }

  static async clearHistory(context: Context): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, Constants.PREF_STORE_NAME);
      await pref.put(Constants.PREF_HISTORY_KEY, '[]');
      await pref.flush();
      hilog.info(0x0000, 'PreferencesUtil', 'clearHistory success');
    } catch (err) {
      hilog.error(0x0000, 'PreferencesUtil', 'clearHistory failed: ' + String(err));
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('清空历史记录失败');
    }
  }
}
