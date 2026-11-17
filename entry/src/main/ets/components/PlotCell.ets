import { Plot, PlotState, getVegInfo } from '../game/GameModel'
import { ScreenUtil } from '../common/ScreenUtil'

// 单个菜地格子：根据地块状态渲染 空地/种子/生长/成熟
@Component
export struct PlotCell {
  @ObjectLink plot: Plot
  @Prop selected: boolean = false
  @Prop showWater: boolean = false
  @Prop guideActive: boolean = false
  onPlotClick: (id: number) => void = (id: number) => {
  }

  private growProgress(): number {
    if (this.plot.totalSeconds <= 0) {
      return 0
    }
    const elapsed: number = this.plot.totalSeconds - this.plot.remainSeconds
    return elapsed / this.plot.totalSeconds
  }

  private cellEmoji(): string {
    if (this.plot.state === PlotState.EMPTY) {
      return '➕'
    }
    if (this.plot.state === PlotState.SEEDED) {
      return '🌰'
    }
    if (this.plot.state === PlotState.GROWING) {
      if (this.growProgress() < 0.5) {
        return '🌱'
      }
      return '🌿'
    }
    return getVegInfo(this.plot.vegType).emoji
  }

  private cellEmojiSize(): number {
    if (this.plot.state === PlotState.MATURE) {
      return 42
    }
    if (this.plot.state === PlotState.EMPTY) {
      return 26
    }
    return 32
  }

  private cellLabel(): string {
    if (this.plot.state === PlotState.EMPTY) {
      return '空地'
    }
    if (this.plot.state === PlotState.SEEDED) {
      return '待浇水'
    }
    if (this.plot.state === PlotState.GROWING) {
      return `${this.plot.remainSeconds}s`
    }
    return '可收获!'
  }

  private soilColor(): string {
    if (this.plot.state === PlotState.EMPTY) {
      return '#D7A86E'
    }
    if (this.plot.state === PlotState.MATURE) {
      return '#C89B62'
    }
    return '#BE8F5C'
  }

  private cellBorderColor(): string {
    if (this.plot.state === PlotState.MATURE) {
      return '#FFC107'
    }
    if (this.selected) {
      return '#4CAF50'
    }
    return '#93714C'
  }

  // 成熟态呼吸放大；首局引导时空地脉冲提示可播种
  private cellScale(): ScaleOptions {
    if (this.plot.state === PlotState.MATURE) {
      return { x: 1.06, y: 1.06 }
    }
    if (this.guideActive && this.plot.state === PlotState.EMPTY) {
      return { x: 1.05, y: 1.05 }
    }
    return { x: 1, y: 1 }
  }

  private cellBorderWidth(): number {
    if (this.selected || this.plot.state === PlotState.MATURE) {
      return 3
    }
    return 2
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: ScreenUtil.w(4) }) {
        Text(this.cellEmoji())
          .fontSize(ScreenUtil.f(this.cellEmojiSize()))
          .transition(TransitionEffect.scale({ x: 0.4, y: 0.4 })
            .combine(TransitionEffect.OPACITY)
            .animation({ duration: 250, curve: Curve.EaseOut }))
        Text(this.cellLabel())
          .fontSize(ScreenUtil.f(11))
          .fontColor('#4E342E')
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Center)

      if (this.plot.state === PlotState.GROWING) {
        Progress({ value: this.growProgress() * 100, total: 100, type: ProgressType.Linear })
          .width('72%')
          .height(ScreenUtil.w(5))
          .color('#66BB6A')
          .borderRadius(ScreenUtil.w(3))
          .position({ x: '14%', y: '82%' })
      }

      if (this.plot.state === PlotState.SEEDED) {
        // 已播种待浇水角标
        Text('💧')
          .fontSize(ScreenUtil.f(14))
          .position({ x: '72%', y: '5%' })
      }

      if (this.showWater) {
        Column({ space: ScreenUtil.w(1) }) {
          Text('💧').fontSize(ScreenUtil.f(13))
          Text('💧').fontSize(ScreenUtil.f(11))
          Text('💧').fontSize(ScreenUtil.f(9))
        }
        .transition(TransitionEffect.translate({ y: ScreenUtil.w(-12) })
          .combine(TransitionEffect.OPACITY)
          .animation({ duration: 500, curve: Curve.EaseIn }))
      }
    }
    .width('100%')
    .aspectRatio(1.05)
    .scale(this.cellScale())
    .animation({ duration: 750, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
    .borderRadius(ScreenUtil.w(14))
    .backgroundColor(this.soilColor())
    .border({
      width: ScreenUtil.w(this.cellBorderWidth()),
      color: this.cellBorderColor(),
      radius: ScreenUtil.w(14)
    })
    .onClick(() => {
      this.onPlotClick(this.plot.id)
    })
  }
}
