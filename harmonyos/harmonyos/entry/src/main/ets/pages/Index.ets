import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpService } from '../service/HttpService';
import { Constants } from '../common/Constants';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileIo, picker } from '@kit.CoreFileKit';

interface SlotItem {
  label: string;
  slot: string;
  imageUri: string;
}

@Entry
@Component
struct Index {
  @State frontImageUri: string = '';
  @State sideImageUri: string = '';
  @State backImageUri: string = '';
  @State frontFilePath: string = '';
  @State sideFilePath: string = '';
  @State backFilePath: string = '';
  @State isLoading: boolean = false;
  @State loadingStep: number = 0;
  @State serverConnected: boolean = false;
  @State errorMessage: string = '';

  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.checkServer();
  }

  async checkServer(): Promise<void> {
    this.serverConnected = await HttpService.healthCheck();
  }

  showPickerMenu(slot: string): void {
    if (this.isLoading) {
      return;
    }
    hilog.info(0x0000, 'Index', 'showPickerMenu called for slot: ' + slot);
    AlertDialog.show({
      title: '选择照片来源',
      message: '请选择照片来源方式',
      buttons: [
        {
          value: '拍照',
          action: () => {
            hilog.info(0x0000, 'Index', 'User selected camera for slot: ' + slot);
            this.takePhoto(slot);
          }
        },
        {
          value: '从相册选择',
          action: () => {
            hilog.info(0x0000, 'Index', 'User selected album for slot: ' + slot);
            this.pickPhoto(slot);
          }
        },
        {
          value: '从文件选择',
          action: () => {
            hilog.info(0x0000, 'Index', 'User selected file for slot: ' + slot);
            this.pickFile(slot);
          }
        }
      ]
    });
  }

  async takePhoto(slot: string): Promise<void> {
    try {
      hilog.info(0x0000, 'Index', 'takePhoto started for slot: ' + slot);
      const pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      };
      const result: cameraPicker.PickerResult =
        await cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile);

      hilog.info(0x0000, 'Index', 'cameraPicker.pick returned, resultCode: ' + result.resultCode);
      if (result.resultCode === 0 && result.resultUri) {
        hilog.info(0x0000, 'Index', 'Processing image from URI: ' + result.resultUri);
        const filePath = await this.processAndCacheImage(result.resultUri);
        this.setImageForSlot(slot, result.resultUri, filePath);
        hilog.info(0x0000, 'Index', 'takePhoto success: ' + slot + ', filePath: ' + filePath);
      } else {
        hilog.warn(0x0000, 'Index', 'takePhoto failed or cancelled, resultCode: ' + result.resultCode);
      }
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      hilog.error(0x0000, 'Index', 'takePhoto exception: ' + errMsg);
      if (errMsg && !errMsg.includes('cancel') && !errMsg.includes('取消')) {
        this.errorMessage = '拍照失败: ' + errMsg;
        AlertDialog.show({
          title: '拍照失败',
          message: '请确保已授予相机权限\n错误信息: ' + errMsg,
        });
      }
    }
  }

  async pickPhoto(slot: string): Promise<void> {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const uri = photoSelectResult.photoUris[0];
        const filePath = await this.processAndCacheImage(uri);
        this.setImageForSlot(slot, uri, filePath);
        hilog.info(0x0000, 'Index', 'pickPhoto success: ' + slot);
      }
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      hilog.error(0x0000, 'Index', 'pickPhoto failed: ' + errMsg);
      if (errMsg && !errMsg.includes('cancel')) {
        this.errorMessage = '选择照片失败: ' + errMsg;
      }
    }
  }

  async pickFile(slot: string): Promise<void> {
    try {
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      let result: Array<string> = await documentPicker.select({
        maxSelectNumber: 1,
        selectMode: picker.DocumentSelectMode.FILE
      });
      if (result && result.length > 0) {
        let uri: string = result[0];
        let filePath: string = await this.processAndCacheImage(uri);
        this.setImageForSlot(slot, uri, filePath);
        hilog.info(0x0000, 'Index', 'pickFile success: ' + slot);
      }
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      hilog.error(0x0000, 'Index', 'pickFile failed: ' + errMsg);
      if (errMsg && !errMsg.includes('cancel')) {
        this.errorMessage = '选择文件失败: ' + errMsg;
      }
    }
  }

  async processAndCacheImage(uri: string): Promise<string> {
    try {
      const compressedUri: string = await this.compressImage(uri) ?? uri;
      const srcFile = fileIo.openSync(compressedUri, fileIo.OpenMode.READ_ONLY);
      const cacheDir = this.context.cacheDir;
      const fileName = 'photo_' + Date.now().toString() + '_' + Math.random().toString(36).substring(2, 8) + '.jpg';
      const destPath = cacheDir + '/' + fileName;
      const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const stat = fileIo.statSync(srcFile.fd);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(srcFile.fd, buf);
      fileIo.writeSync(destFile.fd, buf);
      fileIo.closeSync(srcFile.fd);
      fileIo.closeSync(destFile.fd);
      const destStat = fileIo.statSync(destPath);
      if (destStat.size > Constants.MAX_FILE_SIZE) {
        fileIo.unlinkSync(destPath);
        throw new Error('图片文件过大，请选择小于32MB的图片');
      }
      return destPath;
    } catch (err) {
      hilog.error(0x0000, 'Index', 'processAndCacheImage failed: ' + String(err));
      if (err instanceof Error && err.message.includes('图片文件过大')) {
        throw err;
      }
      return uri;
    }
  }

  async compressImage(uri: string): Promise<string | null> {
    try {
      const imageSource = image.createImageSource(uri);
      const imageInfo = await imageSource.getImageInfo();
      if (imageInfo.size.width <= Constants.MAX_IMAGE_SIZE &&
        imageInfo.size.height <= Constants.MAX_IMAGE_SIZE) {
        imageSource.release();
        return null;
      }
      const scale = Constants.MAX_IMAGE_SIZE / Math.max(imageInfo.size.width, imageInfo.size.height);
      const targetWidth = Math.round(imageInfo.size.width * scale);
      const targetHeight = Math.round(imageInfo.size.height * scale);
      const decodingOptions: image.DecodingOptions = {
        desiredSize: { width: targetWidth, height: targetHeight },
        editable: true,
      };
      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 85,
      };
      const filePath = this.context.cacheDir + '/compressed_' + Date.now().toString() + '.jpg';
      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const data = await packer.packing(pixelMap, packOpts);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file.fd);
      pixelMap.release();
      packer.release();
      imageSource.release();
      return filePath;
    } catch (err) {
      hilog.warn(0x0000, 'Index', 'compressImage fallback: ' + String(err));
      return null;
    }
  }

  setImageForSlot(slot: string, uri: string, filePath: string): void {
    this.errorMessage = '';
    if (slot === 'front') {
      this.frontImageUri = uri;
      this.frontFilePath = filePath;
    } else if (slot === 'side') {
      this.sideImageUri = uri;
      this.sideFilePath = filePath;
    } else {
      this.backImageUri = uri;
      this.backFilePath = filePath;
    }
  }

  clearSlot(slot: string): void {
    if (this.isLoading) {
      return;
    }
    if (slot === 'front') {
      this.frontImageUri = '';
      this.frontFilePath = '';
    } else if (slot === 'side') {
      this.sideImageUri = '';
      this.sideFilePath = '';
    } else {
      this.backImageUri = '';
      this.backFilePath = '';
    }
  }

  async startAnalysis(): Promise<void> {
    if (!this.frontFilePath || !this.sideFilePath || !this.backFilePath) {
      AlertDialog.show({ message: '请先上传正面、侧面、背面三张照片' });
      return;
    }
    this.isLoading = true;
    this.loadingStep = 1;
    this.errorMessage = '';
    try {
      this.loadingStep = 1;
      await new Promise<void>((resolve) => setTimeout(resolve, 300));
      this.loadingStep = 2;
      const response = await HttpService.uploadAndAnalyze(
        this.frontFilePath,
        this.sideFilePath,
        this.backFilePath
      );
      this.loadingStep = 3;
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
      router.pushUrl({
        url: 'pages/ResultPage',
        params: {
          analysis: response.analysis,
          message: response.message,
        }
      });
      this.clearTempFiles();
    } catch (err) {
      const msg = err instanceof Error ? err.message : '网络错误，请检查服务器是否运行';
      this.errorMessage = msg;
      AlertDialog.show({
        title: '分析失败',
        message: msg,
      });
    } finally {
      this.isLoading = false;
      this.loadingStep = 0;
    }
  }

  clearTempFiles(): void {
    try {
      const files = [this.frontFilePath, this.sideFilePath, this.backFilePath];
      for (const f of files) {
        if (f && f.startsWith(this.context.cacheDir)) {
          try {
            fileIo.accessSync(f);
            fileIo.unlinkSync(f);
          } catch (e) {
            // ignored
          }
        }
      }
    } catch (e) {
      hilog.warn(0x0000, 'Index', 'clearTempFiles failed: ' + String(e));
    }
  }

  goHistory(): void {
    router.pushUrl({ url: 'pages/HistoryPage' });
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('智能体态分析')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Blank()
          Button({ type: ButtonType.Normal }) {
            Text('历史记录')
              .fontSize(13)
              .fontColor('#0EA5E9')
          }
          .backgroundColor('#F0F9FF')
          .borderRadius(8)
          .height(32)
          .onClick(() => this.goHistory())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(this.serverConnected ? '#059669' : '#DC2626')
          Text(this.serverConnected ? '服务器已连接' : '服务器未连接')
            .fontSize(12)
            .fontColor(this.serverConnected ? '#059669' : '#DC2626')
            .margin({ left: 6 })
          if (!this.serverConnected) {
            Text('（点击重试）')
              .fontSize(11)
              .fontColor('#0EA5E9')
              .margin({ left: 4 })
              .onClick(() => this.checkServer())
          }
        }
        .padding({ left: 16, top: 4 })

        Column() {
          Text('拍摄要求')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0369A1')
            .margin({ bottom: 6 })
          Text('全身入镜 · 身体站直 · 穿贴身衣物 · 光线充足')
            .fontSize(12)
            .fontColor('#64748B')
        }
        .width('90%')
        .padding(14)
        .margin({ top: 12, bottom: 12 })
        .backgroundColor('#F0F9FF')
        .borderRadius(12)
        .border({ width: 1, color: '#BAE6FD' })

      Row({ space: 10 }) {
        this.PhotoSlot({ label: '正面', slot: 'front', imageUri: this.frontImageUri })
        this.PhotoSlot({ label: '侧面', slot: 'side', imageUri: this.sideImageUri })
        this.PhotoSlot({ label: '背面', slot: 'back', imageUri: this.backImageUri })
      }
        .width('92%')
        .margin({ top: 8 })

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor('#DC2626')
            .margin({ top: 8 })
            .padding({ left: 16, right: 16 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Button({ type: ButtonType.Normal }) {
          Text('开始分析')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('80%')
        .height(50)
        .margin({ top: 24 })
        .borderRadius(12)
        .backgroundColor(
          (this.frontImageUri && this.sideImageUri && this.backImageUri)
            ? '#0EA5E9' : '#94A3B8'
        )
        .enabled(!this.isLoading && !!(this.frontImageUri && this.sideImageUri && this.backImageUri))
        .onClick(() => this.startAnalysis())

        Text('基于 AI 大模型的三视图体态评估系统')
          .fontSize(11)
          .fontColor('#94A3B8')
          .margin({ top: 20 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#EEF4F8')

      if (this.isLoading) {
        this.LoadingOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PhotoSlot(slotItem: SlotItem) {
    Column() {
      Text(slotItem.label)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .margin({ bottom: 8 })

      Stack({ alignContent: Alignment.Center }) {
        if (slotItem.imageUri) {
          Image(slotItem.imageUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius(12)

          Button({ type: ButtonType.Circle }) {
            Text('x')
              .fontSize(12)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .width(24)
          .height(24)
          .backgroundColor('rgba(0,0,0,0.5)')
          .position({ right: 4, top: 4 })
          .onClick(() => this.clearSlot(slotItem.slot))
          .hitTestBehavior(HitTestMode.Block)
        } else {
          Column() {
            Text('+')
              .fontSize(28)
              .fontColor('#94A3B8')
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 4 })
            Text('点击拍照')
              .fontSize(11)
              .fontColor('#94A3B8')
          }
        }
      }
      .width('100%')
      .height(130)
      .borderRadius(12)
      .border({
        width: 1.5,
        color: slotItem.imageUri ? '#0EA5E9' : '#CBD5E1',
        style: slotItem.imageUri ? BorderStyle.Solid : BorderStyle.Dashed
      })
      .backgroundColor('#F8FAFC')
      .onClick(() => {
        this.showPickerMenu(slotItem.slot);
      })
    }
    .layoutWeight(1)
  }

  @Builder
  LoadingOverlay() {
    if (this.isLoading) {
      Column() {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#0EA5E9')
            .margin({ bottom: 16 })

          Text('正在分析体态')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0EA5E9')
            .margin({ bottom: 16 })

          Column({ space: 8 }) {
            this.StepRow(1, '压缩图片')
            this.StepRow(2, '上传照片 & AI 检测')
            this.StepRow(3, '生成分析结果')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .width('80%')
        .padding(32)
        .backgroundColor(Color.White)
        .borderRadius(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(15, 23, 42, 0.45)')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  StepRow(step: number, text: string) {
    Row({ space: 8 }) {
      if (this.loadingStep > step) {
        Text('v').fontSize(14).fontColor('#059669').fontWeight(FontWeight.Bold)
        Text(text).fontSize(13).fontColor('#059669')
      } else if (this.loadingStep === step) {
        LoadingProgress().width(14).height(14).color('#0EA5E9')
        Text(text).fontSize(13).fontColor('#0EA5E9').fontWeight(FontWeight.Bold)
      } else {
        Text('o').fontSize(14).fontColor('#94A3B8')
        Text(text).fontSize(13).fontColor('#94A3B8')
      }
    }
  }
}
