import { ScreenUtil } from '../common/ScreenUtil'
import { VegType, VEG_INFO_LIST, VegInfo, getVegInfo } from '../game/GameModel'

// 一键工作弹窗：选种子一键播种（空地）/ 一键浇水（已播种）
@Component
export struct OneClickDialog {
  @Prop emptyCount: number = 0
  @Prop seededCount: number = 0
  @Prop selectedSeed: VegType = VegType.CARROT
  onSow: (type: VegType) => void = (type: VegType) => {
  }
  onWater: () => void = () => {
  }
  onClose: () => void = () => {
  }

  private sowSubLabel(): string {
    if (this.emptyCount <= 0) {
      return '当前没有空地'
    }
    return `空地 × ${this.emptyCount} · 全部种上${getVegInfo(this.selectedSeed).name}`
  }

  private waterSubLabel(): string {
    if (this.seededCount <= 0) {
      return '当前没有待浇水的地块'
    }
    return `已播种 × ${this.seededCount} · 浇水后开始生长`
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
        Text('⚡ 一键工作')
          .fontSize(ScreenUtil.f(17))
          .fontWeight(FontWeight.Bold)
          .fontColor('#3E2723')

        Row({ space: ScreenUtil.w(8) }) {
          ForEach(VEG_INFO_LIST, (seedItem: VegInfo) => {
            Column({ space: ScreenUtil.w(2) }) {
              Text(seedItem.emoji)
                .fontSize(ScreenUtil.f(22))
              Text(seedItem.name)
                .fontSize(ScreenUtil.f(11))
                .fontColor('#3E2723')
                .fontWeight(FontWeight.Medium)
              Text(`${seedItem.growSeconds}秒 · 售${seedItem.price}💰`)
                .fontSize(ScreenUtil.f(9))
                .fontColor('#795548')
            }
            .layoutWeight(1)
            .padding({ top: ScreenUtil.w(8), bottom: ScreenUtil.w(8) })
            .borderRadius(ScreenUtil.w(12))
            .backgroundColor(seedItem.themeColor)
            .border({
              width: this.selectedSeed === seedItem.type ? ScreenUtil.w(3) : ScreenUtil.w(2),
              color: this.selectedSeed === seedItem.type ? '#43A047' : '#FFFFFF',
              radius: ScreenUtil.w(12)
            })
            .scale(this.selectedSeed === seedItem.type ?
              { x: 1.05, y: 1.05 } : { x: 1, y: 1 })
            .animation({ duration: 120, curve: Curve.EaseOut })
            .onClick(() => {
              this.selectedSeed = seedItem.type
            })
          }, (seedItem: VegInfo): string => 'seed-' + seedItem.type)
        }
        .width('100%')

        Row({ space: ScreenUtil.w(12) }) {
          Text('🌰')
            .fontSize(ScreenUtil.f(26))
          Column({ space: ScreenUtil.w(3) }) {
            Text('一键播种')
              .fontSize(ScreenUtil.f(15))
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(this.sowSubLabel())
              .fontSize(ScreenUtil.f(11))
              .fontColor('#FFFFFFCC')
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({
          left: ScreenUtil.w(16),
          right: ScreenUtil.w(16),
          top: ScreenUtil.w(14),
          bottom: ScreenUtil.w(14)
        })
        .borderRadius(ScreenUtil.w(16))
        .backgroundColor(this.emptyCount > 0 ? '#66BB6A' : '#9E9E9E')
        .opacity(this.emptyCount > 0 ? 1 : 0.6)
        .onClick(() => {
          if (this.emptyCount > 0) {
            this.onSow(this.selectedSeed)
          }
        })

        Row({ space: ScreenUtil.w(12) }) {
          Text('💧')
            .fontSize(ScreenUtil.f(26))
          Column({ space: ScreenUtil.w(3) }) {
            Text('一键浇水')
              .fontSize(ScreenUtil.f(15))
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(this.waterSubLabel())
              .fontSize(ScreenUtil.f(11))
              .fontColor('#FFFFFFCC')
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({
          left: ScreenUtil.w(16),
          right: ScreenUtil.w(16),
          top: ScreenUtil.w(14),
          bottom: ScreenUtil.w(14)
        })
        .borderRadius(ScreenUtil.w(16))
        .backgroundColor(this.seededCount > 0 ? '#42A5F5' : '#9E9E9E')
        .opacity(this.seededCount > 0 ? 1 : 0.6)
        .onClick(() => {
          if (this.seededCount > 0) {
            this.onWater()
          }
        })

        Text('先选种子再一键播种（默认上次选择），播种后可用一键浇水批量养护')
          .fontSize(ScreenUtil.f(11))
          .fontColor('#8D6E63')
          .textAlign(TextAlign.Center)
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
