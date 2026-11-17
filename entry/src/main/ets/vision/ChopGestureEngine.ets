// 切菜手势判定引擎：追踪手腕归一化纵坐标，识别“抬起→快速下切”动作
// yNorm 为手腕在画面中的纵向位置（0 顶部，1 底部），值变小代表手抬高
const SAMPLE_WINDOW_MS = 1000
const CHOP_DROP_THRESHOLD = 0.12
const CHOP_COOLDOWN_MS = 650

interface ChopSample {
  yNorm: number
  tsMs: number
}

export class ChopGestureEngine {
  private samples: ChopSample[] = []
  private lastChopTs: number = 0
  onChop: () => void = () => {
  }

  update(yNorm: number, tsMs: number): void {
    const kept: ChopSample[] = []
    for (const sample of this.samples) {
      if (tsMs - sample.tsMs <= SAMPLE_WINDOW_MS) {
        kept.push(sample)
      }
    }
    kept.push({ yNorm: yNorm, tsMs: tsMs })
    this.samples = kept
    if (tsMs - this.lastChopTs < CHOP_COOLDOWN_MS) {
      return
    }
    let minY: number = Number.MAX_VALUE
    let minYTs: number = 0
    for (const sample of this.samples) {
      if (sample.yNorm < minY) {
        minY = sample.yNorm
        minYTs = sample.tsMs
      }
    }
    if (minY >= Number.MAX_VALUE) {
      return
    }
    const drop: number = yNorm - minY
    if (drop >= CHOP_DROP_THRESHOLD && tsMs - minYTs <= SAMPLE_WINDOW_MS) {
      this.lastChopTs = tsMs
      this.samples = []
      this.onChop()
    }
  }

  reset(): void {
    this.samples = []
    this.lastChopTs = 0
  }
}
