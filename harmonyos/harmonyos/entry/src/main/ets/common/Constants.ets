/**
 * 应用常量配置
 */
export class Constants {
  // 后端服务器地址：改为运行 Flask 后端的机器的局域网 IP（手机与后端需同一网络）
  static readonly SERVER_URL: string = 'http://192.168.1.100:5000';

  // 本地存储键名
  static readonly PREF_STORE_NAME: string = 'titaifenxi_prefs';
  static readonly PREF_HISTORY_KEY: string = 'analysis_history';

  // 图片限制
  static readonly MAX_IMAGE_SIZE: number = 1920;
  static readonly MAX_FILE_SIZE: number = 32 * 1024 * 1024;
  static readonly JPEG_QUALITY: number = 85;

  // 网络超时（毫秒）
  static readonly CONNECT_TIMEOUT: number = 10000;
  static readonly UPLOAD_TIMEOUT: number = 60000;
  static readonly HEALTH_CHECK_TIMEOUT: number = 5000;

  // 历史记录最大条数
  static readonly MAX_HISTORY_COUNT: number = 20;

  // 颜色主题
  static readonly COLOR_PRIMARY: string = '#0EA5E9';
  static readonly COLOR_SUCCESS: string = '#059669';
  static readonly COLOR_WARNING: string = '#CA8A04';
  static readonly COLOR_DANGER: string = '#DC2626';
  static readonly COLOR_ORANGE: string = '#EA580C';
  static readonly COLOR_BG: string = '#EEF4F8';
  static readonly COLOR_CARD: string = '#FFFFFF';
  static readonly COLOR_TEXT_PRIMARY: string = '#0F172A';
  static readonly COLOR_TEXT_SECONDARY: string = '#64748B';
  static readonly COLOR_TEXT_HINT: string = '#94A3B8';
  static readonly COLOR_BORDER: string = '#CBD5E1';
  static readonly COLOR_PRIMARY_LIGHT: string = '#F0F9FF';
  static readonly COLOR_PRIMARY_BORDER: string = '#BAE6FD';
}
