/**
 * 分布式数据管理服务
 * 通过 distributedKVStore 实现同账号设备间体态报告同步
 * 手机评估完成 → 写入分布式 KV → 平板/HarmonyOS PC 自动读取
 *
 * 注意：当前编译环境缺少 @kit.DistributedKVStore 的 ArkTS SDK 配置，
 * 分布式同步功能暂用空实现，避免编译错误。待 SDK 配置完整后启用。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AnalysisResult } from '../model/AnalysisResult';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE_ID: string = 'posture_distributed_store';
const KEY_LATEST_RESULT: string = 'latest_analysis_result';
const KEY_LATEST_SCORE: string = 'latest_score';
const KEY_LATEST_DATE: string = 'latest_date';

export class DistributedService {
  private static isInitialized: boolean = false;

  static async init(context: Context): Promise<boolean> {
    if (DistributedService.isInitialized) {
      return true;
    }
    DistributedService.isInitialized = true;
    hilog.warn(0x0000, 'DistributedService',
      'init skipped: SDK config not available, distributed sync disabled');
    return false;
  }

  static async saveResult(score: string, result: AnalysisResult): Promise<void> {
    hilog.warn(0x0000, 'DistributedService', 'saveResult skipped: SDK config not available');
  }

  static async getLatestScore(): Promise<string> {
    hilog.warn(0x0000, 'DistributedService', 'getLatestScore skipped: SDK config not available');
    return '';
  }

  static async getLatestResult(): Promise<AnalysisResult | null> {
    hilog.warn(0x0000, 'DistributedService', 'getLatestResult skipped: SDK config not available');
    return null;
  }
}
