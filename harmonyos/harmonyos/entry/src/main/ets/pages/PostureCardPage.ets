/**
 * 元服务卡片 Widget 页面 — 2×2 桌面卡片
 * 展示最新体态评分、等级、评估时间，点击跳转 App 首页
 */
@Entry
@Component
struct PostureCardPage {
  @LocalStorageProp('score') score: string = '--';
  @LocalStorageProp('level') level: string = '等待评估';
  @LocalStorageProp('lastTime') lastTime: string = '尚未评估';

  build() {
    Stack() {
      Column() {
        Text('体态评估')
          .fontSize(11)
          .fontColor('#BAE6FD')
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 4 })

        Text(this.score)
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .fontFamily('sans-serif-medium')

        Text(this.level)
          .fontSize(13)
          .fontColor('#BFDBFE')
          .margin({ top: 2, bottom: 6 })

        Text(this.lastTime)
          .fontSize(9)
          .fontColor('rgba(255, 255, 255, 0.6)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(16)
      .linearGradient({
        angle: 135,
        colors: [
          ['#0284C7', 0],
          ['#0EA5E9', 0.5],
          ['#38BDF8', 1]
        ]
      })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        bundleName: 'com.titaifenxi.app',
        abilityName: 'EntryAbility',
        params: {
          targetPage: 'pages/Index'
        }
      });
    })
  }
}
