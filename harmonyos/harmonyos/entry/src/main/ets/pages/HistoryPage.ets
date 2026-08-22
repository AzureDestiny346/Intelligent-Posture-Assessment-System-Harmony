import { router } from '@kit.ArkUI';
import { HistoryItem, METRIC_DEFS, AnalysisResult, MetricDef, MetricResult } from '../model/AnalysisResult';
import { PreferencesUtil } from '../util/PreferencesUtil';
import { DistributedService } from '../service/DistributedService';
import { Constants } from '../common/Constants';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface MetricSummary {
  label: string;
  value: string;
}

@Entry
@Component
struct HistoryPage {
  @State historyList: HistoryItem[] = [];
  @State isLoading: boolean = true;
  @State hasRemoteResult: boolean = false;
  @State remoteScore: string = '';
  private trendSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private trendContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.trendSettings);

  private context = getContext(this);

  aboutToAppear(): void {
    this.loadHistory();
    this.initDistributed();
  }

  async initDistributed(): Promise<void> {
    try {
      const inited = await DistributedService.init(this.context);
      if (inited) {
        const score = await DistributedService.getLatestScore();
        if (score) {
          this.remoteScore = score;
          this.hasRemoteResult = true;
        }
      }
    } catch (err) {
      hilog.warn(0x0000, 'HistoryPage', 'distributed init skipped: ' + String(err));
    }
  }

  async loadHistory(): Promise<void> {
    this.isLoading = true;
    try {
      this.historyList = await PreferencesUtil.getHistory(this.context);
    } catch (err) {
      hilog.error(0x0000, 'HistoryPage', 'loadHistory failed: ' + String(err));
      this.historyList = [];
    } finally {
      this.isLoading = false;
    }
  }

  clearHistory(): void {
    AlertDialog.show({
      title: '确认清空',
      message: '确定要清空所有历史记录吗？此操作不可恢复。',
      buttons: [
        {
          value: '取消',
          action: () => {}
        },
        {
          value: '确定清空',
          action: async () => {
            try {
              await PreferencesUtil.clearHistory(this.context);
              this.historyList = [];
            } catch (err) {
              hilog.error(0x0000, 'HistoryPage', 'clearHistory failed: ' + String(err));
            }
          }
        }
      ]
    });
  }

  async deleteItem(id: number): Promise<void> {
    try {
      await PreferencesUtil.deleteHistoryItem(this.context, id);
      this.historyList = this.historyList.filter(item => item.id !== id);
    } catch (err) {
      hilog.error(0x0000, 'HistoryPage', 'deleteItem failed: ' + String(err));
    }
  }

  viewDetail(item: HistoryItem): void {
    router.pushUrl({
      url: 'pages/ResultPage',
      params: {
        analysis: item.result,
        message: item.date + ' 的分析记录',
      }
    });
  }

  getKeyMetrics(item: HistoryItem): MetricSummary[] {
    const metrics: MetricSummary[] = [];
    for (const def of METRIC_DEFS) {
      const metric = AnalysisResult.getMetricResult(item.result, def.key);
      if (metric && metric.value && metric.value !== '无明显异常' && metric.value !== 'unknown') {
        const summary: MetricSummary = { label: def.label, value: metric.value };
        metrics.push(summary);
        if (metrics.length >= 3) break;
      }
    }
    if (metrics.length === 0) {
      const summary: MetricSummary = { label: '体态', value: '正常' };
      metrics.push(summary);
    }
    return metrics;
  }

  drawTrendChart(): void {
    if (this.historyList.length < 2) return;

    const ctx = this.trendContext;
    const scores = this.getParsedScores();
    if (scores.length < 2) return;

    const width = 320;
    const height = 180;
    const padding = 30;
    const chartWidth = width - padding * 2;
    const chartHeight = height - padding * 2;

    ctx.clearRect(0, 0, width, height);

    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, width, height);

    const maxScore = Math.max(...scores, 100);
    const minScore = Math.min(...scores, 0);
    const scoreRange = maxScore - minScore || 1;

    const ySteps = 4;
    for (let i = 0; i <= ySteps; i++) {
      const y = padding + chartHeight * i / ySteps;
      ctx.beginPath();
      ctx.moveTo(padding, y);
      ctx.lineTo(width - padding, y);
      ctx.strokeStyle = '#F1F5F9';
      ctx.lineWidth = 1;
      ctx.stroke();

      const labelValue = Math.round(maxScore - (maxScore - minScore) * i / ySteps);
      ctx.font = '10px sans-serif';
      ctx.fillStyle = '#94A3B8';
      ctx.textAlign = 'right';
      ctx.fillText(labelValue.toString(), padding - 4, y + 3);
    }

    ctx.beginPath();
    for (let i = 0; i < scores.length; i++) {
      const x = padding + chartWidth * i / (scores.length - 1);
      const y = padding + chartHeight * (1 - (scores[i] - minScore) / scoreRange);
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.strokeStyle = '#0EA5E9';
    ctx.lineWidth = 2;
    ctx.stroke();

    for (let i = 0; i < scores.length; i++) {
      const x = padding + chartWidth * i / (scores.length - 1);
      const y = padding + chartHeight * (1 - (scores[i] - minScore) / scoreRange);

      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#0EA5E9';
      ctx.fill();
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 2;
      ctx.stroke();

      ctx.font = '10px sans-serif';
      ctx.fillStyle = '#334155';
      ctx.textAlign = 'center';
      ctx.fillText(scores[i].toString(), x, y - 10);
    }

    const maxLabels = Math.min(scores.length, 5);
    const step = Math.max(1, Math.floor(scores.length / maxLabels));
    ctx.font = '9px sans-serif';
    ctx.fillStyle = '#94A3B8';
    ctx.textAlign = 'center';
    for (let i = 0; i < scores.length; i += step) {
      const x = padding + chartWidth * i / (scores.length - 1);
      const dateStr = this.historyList[i].date;
      const shortDate = dateStr.length > 10 ? dateStr.substring(5, 10) : dateStr;
      ctx.fillText(shortDate, x, height - 8);
    }
  }

  /**
   * 一次计算所有评分数值，消除 render 中三次重复 map+filter
   */
  private getParsedScores(): number[] {
    return this.historyList.map(item => parseInt(item.score)).filter(s => !isNaN(s));
  }

  getAvgScore(): string {
    const scores = this.getParsedScores();
    if (scores.length === 0) return '--';
    return Math.round(scores.reduce((a, b) => a + b, 0) / scores.length).toString();
  }

  getMaxScore(): string {
    const scores = this.getParsedScores();
    if (scores.length === 0) return '--';
    return Math.max(...scores).toString();
  }

  getMinScore(): string {
    const scores = this.getParsedScores();
    if (scores.length === 0) return '--';
    return Math.min(...scores).toString();
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
        .onClick(() => router.back())

        Text('历史记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (this.historyList.length > 0) {
          Button({ type: ButtonType.Normal }) {
            Text('清空')
              .fontSize(13)
              .fontColor('#DC2626')
          }
          .backgroundColor('#FEF2F2')
          .borderRadius(8)
          .height(32)
          .onClick(() => this.clearHistory())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.historyList.length >= 2) {
        Column() {
          Text('评分趋势')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .margin({ bottom: 12 })

          Canvas(this.trendContext)
            .width(320)
            .height(180)
            .onReady(() => {
              this.drawTrendChart();
            })

          Row({ space: 20 }) {
            Column() {
              Text('平均')
                .fontSize(11)
                .fontColor('#94A3B8')
              Text(this.getAvgScore())
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0EA5E9')
            }

            Column() {
              Text('最高')
                .fontSize(11)
                .fontColor('#94A3B8')
              Text(this.getMaxScore())
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#059669')
            }

            Column() {
              Text('最低')
                .fontSize(11)
                .fontColor('#94A3B8')
              Text(this.getMinScore())
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#EA580C')
            }

            Column() {
              Text('次数')
                .fontSize(11)
                .fontColor('#94A3B8')
              Text(this.historyList.length.toString())
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
            }
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, top: 8 })
        .backgroundColor(Color.White)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)
      }

      if (this.hasRemoteResult) {
        Column() {
          Row({ space: 10 }) {
            Text('📱')
              .fontSize(24)
            Column({ space: 2 }) {
              Text('发现跨设备评估报告')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              Text('来自附近设备 · 评分: ' + this.remoteScore + '分')
                .fontSize(11)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Button({ type: ButtonType.Normal }) {
              Text('查看')
                .fontSize(12)
                .fontColor(Constants.COLOR_PRIMARY)
            }
            .backgroundColor(Constants.COLOR_PRIMARY_LIGHT)
            .borderRadius(6)
            .height(28)
            .onClick(async () => {
              const result = await DistributedService.getLatestResult();
              if (result) {
                router.pushUrl({
                  url: 'pages/ResultPage',
                  params: {
                    analysis: result,
                    message: '来自附近设备的分析记录',
                  }
                });
              }
            })
          }
          .width('100%')
          .padding(14)
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, top: 8 })
        .backgroundColor(Constants.COLOR_PRIMARY_LIGHT)
        .borderRadius(12)
        .border({ width: 1, color: Constants.COLOR_PRIMARY_BORDER })
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#0EA5E9')
          Text('加载中...')
            .fontSize(14)
            .fontColor('#94A3B8')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.historyList.length === 0) {
        Column() {
          Text('暂无历史记录')
            .fontSize(16)
            .fontColor('#94A3B8')
            .margin({ bottom: 8 })
          Text('完成一次体态分析后，点击"保存"即可记录')
            .fontSize(13)
            .fontColor('#94A3B8')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.historyList, (item: HistoryItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.score)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AnalysisResult.getScoreColor(item.score))
                  Text(AnalysisResult.getScoreLevel(item.score))
                    .fontSize(10)
                    .fontColor('#64748B')
                }
                .width(60)
                .height(60)
                .borderRadius(30)
                .backgroundColor('#F8FAFC')
                .border({ width: 2, color: AnalysisResult.getScoreColor(item.score) })
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)

                Column({ space: 6 }) {
                  Text(item.date)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0F172A')

                  Row({ space: 8 }) {
                    ForEach(this.getKeyMetrics(item), (metric: MetricSummary) => {
                      Text(metric.label + ': ' + metric.value)
                        .fontSize(11)
                        .fontColor('#64748B')
                        .backgroundColor('#F1F5F9')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(4)
                    })
                  }
                }
                .layoutWeight(1)
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)

                Column({ space: 4 }) {
                  Button({ type: ButtonType.Normal }) {
                    Text('查看')
                      .fontSize(12)
                      .fontColor('#0EA5E9')
                  }
                  .backgroundColor('#F0F9FF')
                  .borderRadius(6)
                  .height(28)
                  .width(50)
                  .onClick(() => this.viewDetail(item))

                  Button({ type: ButtonType.Normal }) {
                    Text('删除')
                      .fontSize(12)
                      .fontColor('#DC2626')
                  }
                  .backgroundColor('#FEF2F2')
                  .borderRadius(6)
                  .height(28)
                  .width(50)
                  .onClick(() => this.deleteItem(item.id))
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(12)
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EEF4F8')
  }
}
