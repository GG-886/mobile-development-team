import { Plot, PlotState, UNLOCK_PLOT_PRICES } from '../game/GameModel'
import { ScreenUtil } from '../common/ScreenUtil'
import { PlotCell } from './PlotCell'

const GARDEN_COL_INDEXES: number[] = [0, 1]

// 菜园场景：动态地块网格 + 解锁新地块 + 浇水 / 一键工作 / 前往厨房
@Component
export struct GardenScene {
  plots: Plot[] = []
  @Prop selectedPlotId: number = -1
  @Prop wateringPlotId: number = -1
  @Prop unlockedPlotCount: number = 6
  @Prop guideActive: boolean = false
  onPlotClick: (id: number) => void = (id: number) => {
  }
  onWaterClick: () => void = () => {
  }
  onGoKitchen: () => void = () => {
  }
  onOneClickWork: () => void = () => {
  }
  onUnlockPlot: () => void = () => {
  }

  private canWater(): boolean {
    if (this.selectedPlotId < 0 || this.selectedPlotId >= this.plots.length) {
      return false
    }
    return this.plots[this.selectedPlotId].state === PlotState.SEEDED
  }

  private waterBtnColor(): string {
    if (this.canWater()) {
      return '#66BB6A'
    }
    return '#B0BEC5'
  }

  private rowNums(): number[] {
    const rows: number = Math.ceil(this.plots.length / 2)
    const nums: number[] = []
    for (let i = 0; i < rows; i++) {
      nums.push(i)
    }
    return nums
  }

  private unlockPrice(): number {
    const priceIndex: number = this.unlockedPlotCount - 6
    if (priceIndex >= 0 && priceIndex < UNLOCK_PLOT_PRICES.length) {
      return UNLOCK_PLOT_PRICES[priceIndex]
    }
    return UNLOCK_PLOT_PRICES[UNLOCK_PLOT_PRICES.length - 1]
  }

  private unlockLabel(): string {
    return `🔒 解锁第 ${this.unlockedPlotCount + 1} 块地 · ${this.unlockPrice()}💰`
  }

  build() {
    Stack() {
      Column({ space: ScreenUtil.w(10) }) {
        Column({ space: ScreenUtil.w(9) }) {
          ForEach(this.rowNums(), (rowIdx: number) => {
            Row({ space: ScreenUtil.w(9) }) {
              ForEach(GARDEN_COL_INDEXES, (colIdx: number) => {
                if (rowIdx * 2 + colIdx < this.plots.length) {
                  Column() {
                    PlotCell({
                      plot: this.plots[rowIdx * 2 + colIdx],
                      selected: this.selectedPlotId === rowIdx * 2 + colIdx,
                      showWater: this.wateringPlotId === rowIdx * 2 + colIdx,
                      guideActive: this.guideActive,
                      onPlotClick: (id: number): void => {
                        this.onPlotClick(id)
                      }
                    })
                  }
                  .layoutWeight(1)
                } else {
                  Column() {
                  }
                  .layoutWeight(1)
                }
              }, (colIdx: number): string => 'col-' + colIdx)
            }
            .width('100%')
          }, (rowIdx: number): string => 'row-' + rowIdx)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)

        if (this.unlockedPlotCount < 8) {
          Row({ space: ScreenUtil.w(8) }) {
            Text('🌱')
              .fontSize(ScreenUtil.f(16))
            Text(this.unlockLabel())
              .fontSize(ScreenUtil.f(13))
              .fontColor('#5D4037')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text('购买 ➜')
              .fontSize(ScreenUtil.f(12))
              .fontColor('#8D6E63')
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          .padding({
            left: ScreenUtil.w(16),
            right: ScreenUtil.w(16),
            top: ScreenUtil.w(8),
            bottom: ScreenUtil.w(8)
          })
          .borderRadius(ScreenUtil.w(14))
          .backgroundColor('#26A1887F')
          .border({ width: ScreenUtil.w(1), color: '#A1887F', radius: ScreenUtil.w(14) })
          .onClick(() => {
            this.onUnlockPlot()
          })
        }

        Text('点击空地播种 · 播种后选中地块浇水 · 成熟后点击收获')
          .fontSize(ScreenUtil.f(11))
          .fontColor('#6D4C41')
          .maxLines(1)

        Row({ space: ScreenUtil.w(10) }) {
          Button() {
            Text('💧 浇水')
              .fontSize(ScreenUtil.f(14))
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .backgroundColor(this.waterBtnColor())
          .borderRadius(ScreenUtil.w(24))
          .padding({
            left: ScreenUtil.w(18),
            right: ScreenUtil.w(18),
            top: ScreenUtil.w(10),
            bottom: ScreenUtil.w(10)
          })
          .onClick(() => {
            this.onWaterClick()
          })

          Button() {
            Text('⚡ 一键工作')
              .fontSize(ScreenUtil.f(14))
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .backgroundColor('#7CB342')
          .borderRadius(ScreenUtil.w(24))
          .padding({
            left: ScreenUtil.w(18),
            right: ScreenUtil.w(18),
            top: ScreenUtil.w(10),
            bottom: ScreenUtil.w(10)
          })
          .onClick(() => {
            this.onOneClickWork()
          })

          Button() {
            Text('🍳 前往厨房')
              .fontSize(ScreenUtil.f(14))
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .backgroundColor('#8D6E63')
          .borderRadius(ScreenUtil.w(24))
          .padding({
            left: ScreenUtil.w(18),
            right: ScreenUtil.w(18),
            top: ScreenUtil.w(10),
            bottom: ScreenUtil.w(10)
          })
          .onClick(() => {
            this.onGoKitchen()
          })
        }
        .margin({ bottom: ScreenUtil.w(8) })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
