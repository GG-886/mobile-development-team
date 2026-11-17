import { VegType, VEG_INFO_LIST, VegInfo } from '../game/GameModel'
import { ScreenUtil } from '../common/ScreenUtil'

// 播种弹窗：选择 4 种种子之一
@Component
export struct SeedSelectDialog {
  onSeedPick: (type: VegType) => void = (type: VegType) => {
  }
  onClose: () => void = () => {
  }

  private growLabel(item: VegInfo): string {
    return `${item.growSeconds}秒成熟`
  }

  build() {
    Stack() {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        this.onClose()
      })

      Column({ space: ScreenUtil.w(14) }) {
        Text('🌱 选择要播种的种子')
          .fontSize(ScreenUtil.f(17))
          .fontWeight(FontWeight.Bold)
          .fontColor('#3E2723')

        Row({ space: ScreenUtil.w(10) }) {
          ForEach(VEG_INFO_LIST, (seedItem: VegInfo) => {
            Column({ space: ScreenUtil.w(4) }) {
              Text(seedItem.emoji)
                .fontSize(ScreenUtil.f(30))
              Text(seedItem.name)
                .fontSize(ScreenUtil.f(13))
                .fontColor('#3E2723')
                .fontWeight(FontWeight.Medium)
              Text(this.growLabel(seedItem))
                .fontSize(ScreenUtil.f(10))
                .fontColor('#795548')
            }
            .layoutWeight(1)
            .padding({ top: ScreenUtil.w(12), bottom: ScreenUtil.w(12) })
            .borderRadius(ScreenUtil.w(14))
            .backgroundColor(seedItem.themeColor)
            .border({ width: ScreenUtil.w(2), color: '#FFFFFF', radius: ScreenUtil.w(14) })
            .onClick(() => {
              this.onSeedPick(seedItem.type)
            })
          }, (seedItem: VegInfo): string => 'seed-' + seedItem.type)
        }
        .width('100%')

        Text('播种后记得浇水，作物才会生长 💧')
          .fontSize(ScreenUtil.f(11))
          .fontColor('#8D6E63')
      }
      .width('90%')
      .padding(ScreenUtil.w(18))
      .borderRadius(ScreenUtil.w(20))
      .backgroundColor('#FFF8E1')
      .transition(TransitionEffect.scale({ x: 0.85, y: 0.85 })
        .combine(TransitionEffect.OPACITY)
        .animation({ duration: 200, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
  }
}
