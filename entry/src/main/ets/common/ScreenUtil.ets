import { display } from '@kit.ArkUI'

// 设计基准：360vp 宽的普通手机（约 3:2 至 9:19.5 竖屏）
const DESIGN_WIDTH_VP = 360
const DESIGN_HEIGHT_VP = 780
const MIN_LAYOUT_SCALE = 0.8
const MAX_LAYOUT_SCALE = 1.45
const MIN_FONT_SCALE = 0.85
const MAX_FONT_SCALE = 1.2

// 屏幕适配工具：按实际屏幕与设计基准的比例缩放尺寸，适配不同分辨率/折叠屏/平板
export class ScreenUtil {
  private static layoutScale: number = 0
  private static fontScale: number = 0
  private static inited: boolean = false

  private static init(): void {
    if (ScreenUtil.inited) {
      return
    }
    try {
      const disp = display.getDefaultDisplaySync()
      const density: number = disp.densityPixels > 0 ? disp.densityPixels : 3
      const widthVp: number = disp.width / density
      const heightVp: number = disp.height / density
      const rawScale: number = Math.min(widthVp / DESIGN_WIDTH_VP, heightVp / DESIGN_HEIGHT_VP)
      ScreenUtil.layoutScale = Math.min(Math.max(rawScale, MIN_LAYOUT_SCALE), MAX_LAYOUT_SCALE)
      ScreenUtil.fontScale = Math.min(Math.max(rawScale, MIN_FONT_SCALE), MAX_FONT_SCALE)
    } catch (err) {
      ScreenUtil.layoutScale = 1
      ScreenUtil.fontScale = 1
    }
    ScreenUtil.inited = true
  }

  // 缩放布局尺寸（vp）
  static w(designVp: number): number {
    ScreenUtil.init()
    return Math.round(designVp * ScreenUtil.layoutScale * 10) / 10
  }

  // 缩放字号（fp，范围更收敛，避免文字过大/过小）
  static f(designFp: number): number {
    ScreenUtil.init()
    return Math.round(designFp * ScreenUtil.fontScale * 10) / 10
  }

  static getLayoutScale(): number {
    ScreenUtil.init()
    return ScreenUtil.layoutScale
  }
}
