import { http } from '@kit.NetworkKit';
import { Constants } from '../common/Constants';
import { UploadResponse } from '../model/AnalysisResult';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class HttpService {
  private static readonly MAX_RETRIES: number = 2;
  private static readonly RETRY_DELAY: number = 1000;

  static async uploadAndAnalyze(
    frontPath: string,
    sidePath: string,
    backPath: string
  ): Promise<UploadResponse> {
    const httpRequest = http.createHttp();
    const url = Constants.SERVER_URL + '/upload';

    try {
      hilog.info(0x0000, 'HttpService', 'uploadAndAnalyze start');

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'multipart/form-data',
        },
        multiFormDataList: [
          {
            name: 'front_image',
            contentType: 'image/jpeg',
            filePath: frontPath,
          },
          {
            name: 'side_image',
            contentType: 'image/jpeg',
            filePath: sidePath,
          },
          {
            name: 'back_image',
            contentType: 'image/jpeg',
            filePath: backPath,
          },
        ],
        expectDataType: http.HttpDataType.STRING,
        readTimeout: Constants.UPLOAD_TIMEOUT,
        connectTimeout: Constants.CONNECT_TIMEOUT,
      });

      if (response.responseCode === http.ResponseCode.OK) {
        const data: UploadResponse = JSON.parse(response.result as string);
        hilog.info(0x0000, 'HttpService', 'uploadAndAnalyze success');
        return data;
      } else if (response.responseCode === 429) {
        throw new Error('请求过于频繁，请稍后再试');
      } else if (response.responseCode === 413) {
        throw new Error('图片文件过大，请压缩后重试');
      } else if (response.responseCode === 503) {
        throw new Error('AI 服务暂时不可用，请稍后重试');
      } else if (response.responseCode >= 500) {
        throw new Error('服务器错误 (' + response.responseCode.toString() + ')，请稍后重试');
      } else {
        throw new Error('请求失败: ' + response.responseCode.toString());
      }
    } catch (err) {
      hilog.error(0x0000, 'HttpService', 'uploadAndAnalyze failed: ' + String(err));
      if (err instanceof Error) {
        const msg = err.message;
        if (msg.includes('Network') || msg.includes('ECONNREFUSED') || msg.includes('timeout')) {
          throw new Error('无法连接到服务器，请检查网络和服务器状态');
        }
        throw err;
      }
      throw new Error('网络请求异常，请重试');
    } finally {
      httpRequest.destroy();
    }
  }

  static async healthCheck(): Promise<boolean> {
    for (let attempt = 0; attempt <= HttpService.MAX_RETRIES; attempt++) {
      const httpRequest = http.createHttp();
      const url = Constants.SERVER_URL + '/health';

      try {
        const response = await httpRequest.request(url, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          readTimeout: Constants.CONNECT_TIMEOUT,
          connectTimeout: Constants.CONNECT_TIMEOUT,
        });

        if (response.responseCode === http.ResponseCode.OK) {
          hilog.info(0x0000, 'HttpService', 'healthCheck success');
          return true;
        }
      } catch (err) {
        hilog.warn(0x0000, 'HttpService',
          'healthCheck attempt ' + (attempt + 1).toString() + '/' + (HttpService.MAX_RETRIES + 1).toString());
      } finally {
        httpRequest.destroy();
      }

      if (attempt < HttpService.MAX_RETRIES) {
        await new Promise<void>((resolve) => setTimeout(resolve, HttpService.RETRY_DELAY));
      }
    }

    return false;
  }
}
