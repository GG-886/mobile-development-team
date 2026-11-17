import { VegType, RAW_BAG_CAPACITY, VEG_INFO_LIST, VegInfo } from '../game/GameModel'
import { ScreenUtil } from '../common/ScreenUtil'

// 背包弹窗：原始蔬菜 + 切好食材；厨房模式下点击蔬菜放到砧板
@Component
export struct BackpackDialog {
  @Prop rawCounts: number[] = [0, 0, 0, 0]
  @Prop processedCounts: number[] = [0, 0, 0, 0]
  @Prop isKitchenMode: boolean = false
  onRawVegClick: (type: VegType) => void = (type: VegType) => {
  }
  onJumpRecipe: () => void = () => {
  }
  onClose: () => void = () => {
  }

  private rawTotal(): number {
    let sum: number = 0
    for (const count of this.rawCounts) {
      sum += count
    }
    return sum
  }

  private processedTotal(): number {
    let sum: number = 0
    for (const count of this.processedCounts) {
      sum += count
    }
    return sum
  }

  private slotBg(count: number): string {
    if (count > 0) {
      return '#FFFFFF'
    }
    return '#14000000'
  }

  private slotEmojiAlpha(count: number): number {
    if (count > 0) {
      return 1
    }
    return 0.35
  }

  private rawTitle(): string {
    return `🥕 新鲜蔬菜（${this.rawTotal()}/${RAW_BAG_CAPACITY}）`
  }

  private processedTitle(): string {
    return `🍽️ 切好食材（${this.processedTotal()}）`
  }

  @Builder
  RawVegGrid() {
    Row({ space: ScreenUtil.w(10) }) {
      ForEach(VEG_INFO_LIST, (rawItem: VegInfo) => {
        Column({ space: ScreenUtil.w(3) }) {
          Text(rawItem.emoji)
            .fontSize(ScreenUtil.f(28))
            .opacity(this.slotEmojiAlpha(this.rawCounts[rawItem.type]))
          Text(`×${this.rawCounts[rawItem.type]}`)
            .fontSize(ScreenUtil.f(12))
            .fontColor('#5D4037')
            .fontWeight(FontWeight.Bold)
          Text(rawItem.name)
            .fontSize(ScreenUtil.f(10))
            .fontColor('#8D6E63')
        }
        .layoutWeight(1)
        .padding({ top: ScreenUtil.w(10), bottom: ScreenUtil.w(10) })
        .borderRadius(ScreenUtil.w(12))
        .backgroundColor(this.slotBg(this.rawCounts[rawItem.type]))
        .border({ width: ScreenUtil.w(1), color: '#E0D5C8', radius: ScreenUtil.w(12) })
        .onClick(() => {
          if (this.isKitchenMode) {
            this.onRawVegClick(rawItem.type)
          }
        })
      }, (rawItem: VegInfo): string => 'raw-' + rawItem.type)
    }
    .width('100%')
  }

  @Builder
  ProcessedVegGrid() {
    Row({ space: ScreenUtil.w(10) }) {
      ForEach(VEG_INFO_LIST, (cookedItem: VegInfo) => {
        Column({ space: ScreenUtil.w(3) }) {
          Text(cookedItem.processedEmoji)
            .fontSize(ScreenUtil.f(26))
            .opacity(this.slotEmojiAlpha(this.processedCounts[cookedItem.type]))
          Text(`×${this.processedCounts[cookedItem.type]}`)
            .fontSize(ScreenUtil.f(12))
            .fontColor('#5D4037')
            .fontWeight(FontWeight.Bold)
          Text(cookedItem.processedName)
            .fontSize(ScreenUtil.f(10))
            .fontColor('#8D6E63')
        }
        .layoutWeight(1)
        .padding({ top: ScreenUtil.w(10), bottom: ScreenUtil.w(10) })
        .borderRadius(ScreenUtil.w(12))
        .backgroundColor(this.slotBg(this.processedCounts[cookedItem.type]))
        .border({ width: ScreenUtil.w(1), color: '#E0D5C8', radius: ScreenUtil.w(12) })
        .onClick(() => {
          if (this.isKitchenMode) {
            this.onJumpRecipe()
          }
        })
      }, (cookedItem: VegInfo): string => 'cooked-' + cookedItem.type)
    }
    .width('100%')
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

      Column({ space: ScreenUtil.w(13) }) {
        Row() {
          Text('🎒 背包')
            .fontSize(ScreenUtil.f(18))
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
            .layoutWeight(1)
          Text('✕')
            .fontSize(ScreenUtil.f(18))
            .fontColor('#8D6E63')
            .padding({ left: ScreenUtil.w(8), top: ScreenUtil.w(2), bottom: ScreenUtil.w(2) })
            .onClick(() => {
              this.onClose()
            })
        }
        .width('100%')

        Text(this.rawTitle())
          .fontSize(ScreenUtil.f(13))
          .fontColor('#5D4037')
          .fontWeight(FontWeight.Bold)
        this.RawVegGrid()

        Divider()
          .color('#E0D5C8')
          .width('100%')

        Text(this.processedTitle())
          .fontSize(ScreenUtil.f(13))
          .fontColor('#5D4037')
          .fontWeight(FontWeight.Bold)
        this.ProcessedVegGrid()

        if (this.isKitchenMode) {
          if (this.rawTotal() === 0 && this.processedTotal() === 0) {
            Text('背包空空的，先回菜园收获蔬菜吧 🌱')
              .fontSize(ScreenUtil.f(10))
              .fontColor('#A1887F')
          } else {
            Text('点击新鲜蔬菜放上砧板；点击切好食材可去菜谱板做菜 📖')
              .fontSize(ScreenUtil.f(10))
              .fontColor('#A1887F')
          }
        } else {
          if (this.rawTotal() === 0 && this.processedTotal() === 0) {
            Text('收获的蔬菜会存放在这里，去菜园种种看吧 🌱')
              .fontSize(ScreenUtil.f(10))
              .fontColor('#A1887F')
          } else {
            Text('收获的蔬菜会存放在这里')
              .fontSize(ScreenUtil.f(10))
              .fontColor('#A1887F')
          }
        }
      }
      .width('88%')
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
