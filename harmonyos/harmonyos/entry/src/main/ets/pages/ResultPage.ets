import { router } from '@kit.ArkUI';
import { AnalysisResult, METRIC_DEFS, ExerciseItem, HealthRisk, RadarDataItem, MetricDef, MetricResult } from '../model/AnalysisResult';
import { Constants } from '../common/Constants';
import { PreferencesUtil } from '../util/PreferencesUtil';
import { DistributedService } from '../service/DistributedService';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct ResultPage {
  @State analysis: AnalysisResult | null = null;
  @State message: string = '';
  @State showSaveSuccess: boolean = false;
  private radarSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private radarContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.radarSettings);

  private context = getContext(this);

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      const analysisData = params['analysis'];
      if (analysisData instanceof AnalysisResult) {
        this.analysis = analysisData;
      } else if (analysisData) {
        this.analysis = this.parseAnalysisResult(analysisData as Record<string, Object>);
      }
      const msgData = params['message'];
      if (typeof msgData === 'string') {
        this.message = msgData;
      }
    }
  }

  private parseAnalysisResult(data: Record<string, Object>): AnalysisResult {
    const result = new AnalysisResult();
    try {
      result.overall_score = (data['overall_score'] as string) || '';
      result.deep_analysis = (data['deep_analysis'] as string) || '';
      result.advice = (data['advice'] as string[]) || [];
      result.high_low_shoulder = this.parseMetricResult(data['high_low_shoulder'] as Record<string, Object>);
      result.pelvic_lateral_tilt = this.parseMetricResult(data['pelvic_lateral_tilt'] as Record<string, Object>);
      result.pelvic_anterior_tilt = this.parseMetricResult(data['pelvic_anterior_tilt'] as Record<string, Object>);
      result.forward_head = this.parseMetricResult(data['forward_head'] as Record<string, Object>);
      result.round_shoulder = this.parseMetricResult(data['round_shoulder'] as Record<string, Object>);
      result.spinal_asymmetry = this.parseMetricResult(data['spinal_asymmetry'] as Record<string, Object>);
      result.elbow_asymmetry = this.parseMetricResult(data['elbow_asymmetry'] as Record<string, Object>);
      result.leg_length_diff = this.parseMetricResult(data['leg_length_diff'] as Record<string, Object>);
      result.knee_hyperextension = this.parseMetricResult(data['knee_hyperextension'] as Record<string, Object>);
      result.radar_data = this.parseRadarData(data['radar_data'] as Object[]);
      result.exercise_prescription = this.parseExerciseItems(data['exercise_prescription'] as Object[]);
      result.health_risks = this.parseHealthRisks(data['health_risks'] as Object[]);
    } catch (err) {
      hilog.error(0x0000, 'ResultPage', 'parseAnalysisResult failed: ' + String(err));
    }
    return result;
  }

  private parseMetricResult(data: Record<string, Object>): MetricResult {
    const mr = new MetricResult();
    if (data) {
      mr.value = (data['value'] as string) || '';
      mr.confidence = (data['confidence'] as number) || 0;
    }
    return mr;
  }

  private parseRadarData(arr: Object[]): RadarDataItem[] {
    const result: RadarDataItem[] = [];
    if (arr) {
      for (const item of arr) {
        const rd = new RadarDataItem();
        const record = item as Record<string, Object>;
        rd.metric = (record['metric'] as string) || '';
        rd.score = (record['score'] as number) || 0;
        rd.severity = (record['severity'] as string) || '';
        result.push(rd);
      }
    }
    return result;
  }

  private parseExerciseItems(arr: Object[]): ExerciseItem[] {
    const result: ExerciseItem[] = [];
    if (arr) {
      for (const item of arr) {
        const ei = new ExerciseItem();
        const record = item as Record<string, Object>;
        ei.name = (record['name'] as string) || '';
        ei.duration = (record['duration'] as string) || '';
        ei.target = (record['target'] as string) || '';
        ei.tip = (record['tip'] as string) || '';
        result.push(ei);
      }
    }
    return result;
  }

  private parseHealthRisks(arr: Object[]): HealthRisk[] {
    const result: HealthRisk[] = [];
    if (arr) {
      for (const item of arr) {
        const hr = new HealthRisk();
        const record = item as Record<string, Object>;
        hr.metric = (record['metric'] as string) || '';
        hr.severity = (record['severity'] as string) || '';
        hr.risk = (record['risk'] as string) || '';
        hr.desc = (record['desc'] as string) || '';
        result.push(hr);
      }
    }
    return result;
  }

  getMetricResult(key: string): MetricResult {
    if (!this.analysis) {
      return new MetricResult();
    }
    return AnalysisResult.getMetricResult(this.analysis, key);
  }

  getSeverityColor(value: string): string {
    if (value === '无明显异常') return '#059669';
    if (value === '轻度') return '#CA8A04';
    if (value === '中度') return '#EA580C';
    if (value === '重度') return '#DC2626';
    return '#94A3B8';
  }

  getDisplayValue(key: string): string {
    const metric = this.getMetricResult(key);
    return metric.value || '未检测';
  }

  getConfidence(key: string): number {
    const metric = this.getMetricResult(key);
    return metric.confidence || 0;
  }

  getConfidenceDisplay(key: string): string {
    const conf = this.getConfidence(key);
    if (conf > 1) {
      return Math.round(conf).toString() + '%';
    }
    return Math.round(conf * 100).toString() + '%';
  }

  async saveToHistory(): Promise<void> {
    if (!this.analysis) return;

    try {
      await PreferencesUtil.saveHistory(this.context, this.analysis.overall_score, this.analysis);
      // 同时写入分布式 KV，供同账号其他设备读取
      DistributedService.saveResult(this.analysis.overall_score, this.analysis);
      this.showSaveSuccess = true;
      setTimeout(() => {
        this.showSaveSuccess = false;
      }, 2000);
    } catch (err) {
      hilog.error(0x0000, 'ResultPage', 'saveToHistory failed: ' + String(err));
    }
  }

  goBack(): void {
    router.back();
  }

  drawRadarChart(): void {
    if (!this.analysis?.radar_data || this.analysis.radar_data.length === 0) {
      return;
    }

    const ctx = this.radarContext;
    const data = this.analysis.radar_data;
    const centerX = 150;
    const centerY = 150;
    const maxRadius = 110;
    const levels = 4;

    ctx.clearRect(0, 0, 300, 300);

    for (let i = 1; i <= levels; i++) {
      const radius = maxRadius * i / levels;
      ctx.beginPath();
      ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
      ctx.strokeStyle = '#E2E8F0';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    const count = data.length;
    for (let i = 0; i < count; i++) {
      const angle = (Math.PI * 2 * i / count) - Math.PI / 2;
      const x = centerX + maxRadius * Math.cos(angle);
      const y = centerY + maxRadius * Math.sin(angle);
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(x, y);
      ctx.strokeStyle = '#E2E8F0';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    ctx.beginPath();
    for (let i = 0; i < count; i++) {
      const angle = (Math.PI * 2 * i / count) - Math.PI / 2;
      const score = Math.min(data[i].score, 100) / 100;
      const radius = maxRadius * score;
      const x = centerX + radius * Math.cos(angle);
      const y = centerY + radius * Math.sin(angle);
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.closePath();
    ctx.fillStyle = 'rgba(14, 165, 233, 0.25)';
    ctx.fill();
    ctx.strokeStyle = '#0EA5E9';
    ctx.lineWidth = 2;
    ctx.stroke();

    for (let i = 0; i < count; i++) {
      const angle = (Math.PI * 2 * i / count) - Math.PI / 2;
      const score = Math.min(data[i].score, 100) / 100;
      const radius = maxRadius * score;
      const x = centerX + radius * Math.cos(angle);
      const y = centerY + radius * Math.sin(angle);
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#0EA5E9';
      ctx.fill();
    }

    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < count; i++) {
      const angle = (Math.PI * 2 * i / count) - Math.PI / 2;
      const labelRadius = maxRadius + 20;
      const x = centerX + labelRadius * Math.cos(angle);
      const y = centerY + labelRadius * Math.sin(angle);
      ctx.fillStyle = '#334155';
      ctx.fillText(data[i].metric, x, y);
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Normal }) {
          Text('< 返回')
            .fontSize(14)
            .fontColor('#0EA5E9')
        }
        .backgroundColor('#F0F9FF')
        .borderRadius(8)
        .height(32)
        .onClick(() => this.goBack())

        Text('分析报告')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button({ type: ButtonType.Normal }) {
          Text(this.showSaveSuccess ? '已保存' : '保存')
            .fontSize(13)
            .fontColor(this.showSaveSuccess ? '#059669' : '#0EA5E9')
        }
        .backgroundColor(this.showSaveSuccess ? '#F0FDF4' : '#F0F9FF')
        .borderRadius(8)
        .height(32)
        .enabled(!this.showSaveSuccess)
        .onClick(() => this.saveToHistory())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          Column() {
            Text('整体评分')
              .fontSize(14)
              .fontColor('#64748B')
            Text(this.analysis?.overall_score || '--')
              .fontSize(56)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0EA5E9')
              .margin({ top: 4 })
            Text('分')
              .fontSize(16)
              .fontColor('#64748B')
          }
          .width('100%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Center)

          if (this.analysis?.radar_data && this.analysis.radar_data.length > 0) {
            Column() {
              Text('体态雷达图')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .margin({ bottom: 8 })

              Canvas(this.radarContext)
                .width(300)
                .height(300)
                .onReady(() => {
                  this.drawRadarChart();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .alignItems(HorizontalAlign.Center)
          }

          Column() {
            Text('体态指标详情')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
              .margin({ bottom: 12 })

            ForEach(METRIC_DEFS, (item: MetricDef) => {
              Row() {
                Column() {
                  Text(item.label)
                    .fontSize(14)
                    .fontColor('#64748B')
                  Text('视角: ' + item.view)
                    .fontSize(11)
                    .fontColor('#94A3B8')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(this.getDisplayValue(item.key))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getSeverityColor(this.getDisplayValue(item.key)))

                Text(this.getConfidenceDisplay(item.key))
                  .fontSize(11)
                  .fontColor('#94A3B8')
                  .margin({ left: 8 })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 1 }, color: '#F1F5F9' })
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)

          if (this.analysis?.advice && this.analysis.advice.length > 0) {
            Column() {
              Text('改善建议')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .margin({ bottom: 12 })

              ForEach(this.analysis.advice, (item: string, index: number) => {
                Text((index + 1).toString() + '. ' + item)
                  .fontSize(14)
                  .fontColor('#1E40AF')
                  .lineHeight(24)
                  .margin({ bottom: 8 })
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#EFF6FF')
            .borderRadius(12)
            .border({ width: 1, color: '#BFDBFE' })
          }

          if (this.analysis?.deep_analysis) {
            Column() {
              Text('AI 深度解读')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .margin({ bottom: 12 })

              Text(this.analysis.deep_analysis)
                .fontSize(14)
                .fontColor('#78350F')
                .lineHeight(26)
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FEFCE8')
            .borderRadius(12)
            .border({ width: 1, color: '#FDE68A' })
          }

          if (this.analysis?.exercise_prescription && this.analysis.exercise_prescription.length > 0) {
            Column() {
              Text('个性化运动处方')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .margin({ bottom: 12 })

              ForEach(this.analysis.exercise_prescription, (item: ExerciseItem) => {
                Column({ space: 6 }) {
                  Text(item.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#166534')

                  Row({ space: 12 }) {
                    Text('时长: ' + item.duration)
                      .fontSize(12)
                      .fontColor('#64748B')
                    Text('目标: ' + item.target)
                      .fontSize(12)
                      .fontColor('#166534')
                      .backgroundColor('#DCFCE7')
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(4)
                  }

                  Text('提示: ' + item.tip)
                    .fontSize(12)
                    .fontColor('#4B5563')
                    .lineHeight(18)
                }
                .width('100%')
                .padding(14)
                .backgroundColor(Color.White)
                .borderRadius(10)
                .border({ width: { left: 4 }, color: '#22C55E' })
                .margin({ bottom: 10 })
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#F0FDF4')
            .borderRadius(12)
            .border({ width: 1, color: '#86EFAC' })
          }

          if (this.analysis?.health_risks) {
            Column() {
              Text('健康风险预警')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .margin({ bottom: 12 })

              if (this.analysis.health_risks.length === 0) {
                Text('暂无明显健康风险，请继续保持良好体态！')
                  .fontSize(14)
                  .fontColor('#059669')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .padding(12)
              } else {
                ForEach(this.analysis.health_risks, (item: HealthRisk) => {
                  Column() {
                    Row({ space: 10 }) {
                      Column()
                        .width(4)
                        .height(40)
                        .borderRadius(2)
                        .backgroundColor(this.getSeverityColor(item.severity))

                      Column({ space: 6 }) {
                        Row({ space: 8 }) {
                          Text(item.metric)
                            .fontSize(14)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#9A3412')

                          Text(item.severity)
                            .fontSize(11)
                            .fontColor(Color.White)
                            .backgroundColor(this.getSeverityColor(item.severity))
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(4)
                        }

                        Text(item.risk)
                          .fontSize(13)
                          .fontColor('#C2410C')
                          .fontWeight(FontWeight.Medium)

                        Text(item.desc)
                          .fontSize(12)
                          .fontColor('#78350F')
                          .lineHeight(20)
                          .opacity(0.85)
                      }
                      .layoutWeight(1)
                    }
                    .width('100%')
                    .padding(12)
                  }
                  .width('100%')
                  .backgroundColor(Color.White)
                  .borderRadius(8)
                  .margin({ bottom: 8 })
                })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFF7ED')
            .borderRadius(12)
            .border({ width: 1, color: '#FDBA74' })
          }

          Column().height(20)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EEF4F8')
  }
}
