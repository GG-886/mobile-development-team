import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ScreenUtil } from '../common/ScreenUtil'
import { ChopCameraController } from '../vision/ChopCameraController'
import { ChopGestureEngine } from '../vision/ChopGestureEngine'

const TAG = 'GestureChopOverlay'
const DOMAIN = 0x0A11

// 摄像头手势切菜全屏界面：前置相机预览 + 骨骼点检测追踪手腕“抬起→下切”动作
@Component
export struct GestureChopOverlay {
  @Prop vegEmoji: string = ''
  @Prop requiredChops: number = 3
  onChop: (count: number) => void = () => {
  }
  onClose: () => void = () => {
  }

  @State chopCount: number = 0
  @State permissionDenied: boolean = false
  @State cameraReady: boolean = false
  @State errorMsg: string = ''
  @State detectorUnavailable: boolean = false
  @State handSeen: boolean = false
  @State knifeSwing: boolean = false
  @State sparkleVisible: boolean = false

  private xcompController: XComponentController = new XComponentController()
  private cameraCtrl: ChopCameraController = new ChopCameraController()
  private engine: ChopGestureEngine = new ChopGestureEngine()
  private appContext: Context | null = null
  private surfaceId: string = ''
  private surfaceReady: boolean = false
  private permGranted: boolean = false
  private startingCamera: boolean = false
  private knifeAnimTimerId: number = -1
  private sparkleTimerId: number = -1
  private handLostTimerId: number = -1

  aboutToAppear(): void {
    const ctx: Context | undefined = this.getUIContext().getHostContext()
    this.appContext = ctx ?? null
    this.engine.onChop = (): void => {
      this.onGestureChop()
    }
    this.cameraCtrl.onWristDetected = (yNorm: number): void => {
      this.onWristTracked(yNorm)
    }
    this.cameraCtrl.onReady = (): void => {
      this.cameraReady = true
    }
    this.cameraCtrl.onError = (msg: string): void => {
      this.errorMsg = msg
    }
    this.cameraCtrl.onDetectorUnavailable = (): void => {
      this.detectorUnavailable = true
    }
    this.requestCameraPermission()
  }

  aboutToDisappear(): void {
    clearTimeout(this.knifeAnimTimerId)
    clearTimeout(this.sparkleTimerId)
    clearTimeout(this.handLostTimerId)
    this.cameraCtrl.stop()
  }

  private async requestCameraPermission(): Promise<void> {
    if (this.appContext === null) {
      this.permissionDenied = true
      return
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const perms: Array<Permissions> = ['ohos.permission.CAMERA']
      const result = await atManager.requestPermissionsFromUser(this.appContext, perms)
      const status: number = result.authResults.length > 0 ? result.authResults[0] : -1
      if (status === 0) {
        this.permGranted = true
        this.tryStartCamera()
      } else {
        this.permissionDenied = true
      }
    } catch (err) {
      const error = err as BusinessError
      hilog.error(DOMAIN, TAG, 'request camera permission failed: %{public}s', error.message)
      this.permissionDenied = true
    }
  }

  private tryStartCamera(): void {
    if (!this.permGranted || !this.surfaceReady || this.startingCamera || this.appContext === null) {
      return
    }
    this.startingCamera = true
    this.cameraCtrl.start(this.appContext, this.surfaceId)
  }

  private onWristTracked(yNorm: number): void {
    this.handSeen = true
    clearTimeout(this.handLostTimerId)
    this.handLostTimerId = setTimeout(() => {
      this.handSeen = false
    }, 1500)
    this.engine.update(yNorm, Date.now())
  }

  private onGestureChop(): void {
    this.chopCount += 1
    this.knifeSwing = true
    this.sparkleVisible = true
    clearTimeout(this.knifeAnimTimerId)
    this.knifeAnimTimerId = setTimeout(() => {
      this.knifeSwing = false
    }, 260)
    clearTimeout(this.sparkleTimerId)
    this.sparkleTimerId = setTimeout(() => {
      this.sparkleVisible = false
    }, 320)
    this.onChop(this.chopCount)
  }

  private hintMsg(): string {
    if (this.permissionDenied) {
      return '相机权限未开启，无法使用手势切菜'
    }
    if (this.errorMsg !== '') {
      return this.errorMsg
    }
    if (this.detectorUnavailable) {
      return '当前设备不支持 AI 手势识别（模拟器常见），点击屏幕上的蔬菜即可切菜 👆'
    }
    if (!this.cameraReady) {
      return '正在开启相机…'
    }
    if (!this.handSeen) {
      return '请将上半身和手举到镜头前'
    }
    return '举起手，用力向下挥出「切菜」动作！'
  }

  private statusLabel(): string {
    if (!this.cameraReady) {
      return '相机启动中…'
    }
    if (this.detectorUnavailable) {
      return '手势识别不可用 · 点击切菜'
    }
    return this.handSeen ? '已检测到手部' : '正在识别手部…'
  }

  private progressLabel(): string {
    return `✂️ 已切 ${this.chopCount} / ${this.requiredChops} 刀`
  }

  private knifeAngle(): number {
    return this.knifeSwing ? 62 : -14
  }

  private knifeOffsetY(): number {
    return this.knifeSwing ? ScreenUtil.w(52) : 0
  }

  build() {
    Stack() {
      XComponent({ type: XComponentType.SURFACE, controller: this.xcompController })
        .onLoad(() => {
          this.surfaceId = this.xcompController.getXComponentSurfaceId()
          this.surfaceReady = true
          this.tryStartCamera()
        })
        .width('100%')
        .height('100%')

      Column() {
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [['#66000000', 0.0], ['#26000000', 0.35], ['#B3000000', 1.0]]
      })
      .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Button() {
            Text('✕')
              .fontSize(ScreenUtil.f(18))
              .fontColor('#FFFFFF')
          }
          .width(ScreenUtil.w(40))
          .height(ScreenUtil.w(40))
          .borderRadius(ScreenUtil.w(20))
          .backgroundColor('#66000000')
          .onClick(() => {
            this.onClose()
          })

          Text('🎥 手势切菜')
            .fontSize(ScreenUtil.f(18))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Column() {
          }
          .width(ScreenUtil.w(40))
        }
        .width('100%')
        .padding({ left: ScreenUtil.w(16), right: ScreenUtil.w(16), top: ScreenUtil.w(14) })

        Text(this.hintMsg())
          .fontSize(ScreenUtil.f(13))
          .fontColor(this.permissionDenied || this.errorMsg !== '' ? '#FFCC80' : '#E0E0E0')
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .margin({ top: ScreenUtil.w(10) })
          .padding({
            left: ScreenUtil.w(16),
            right: ScreenUtil.w(16),
            top: ScreenUtil.w(6),
            bottom: ScreenUtil.w(6)
          })
          .backgroundColor('#33000000')
          .borderRadius(ScreenUtil.w(16))

        Column() {
        }
        .layoutWeight(1)

        Stack({ alignContent: Alignment.Center }) {
          Column() {
          }
          .width(ScreenUtil.w(232))
          .aspectRatio(1.9)
          .borderRadius(ScreenUtil.w(22))
          .backgroundColor('#DEB887')
          .border({ width: ScreenUtil.w(3), color: '#A0713F', radius: ScreenUtil.w(22) })

          Text(this.vegEmoji)
            .fontSize(ScreenUtil.w(64))

          if (this.sparkleVisible) {
            Text('✨')
              .fontSize(ScreenUtil.w(26))
              .position({ x: '18%', y: '16%' })
            Text('✨')
              .fontSize(ScreenUtil.w(20))
              .position({ x: '74%', y: '24%' })
          }

          Text('🔪')
            .fontSize(ScreenUtil.w(52))
            .position({ x: '62%', y: '2%' })
            .translate({ y: this.knifeOffsetY() })
            .rotate({ angle: this.knifeAngle() })
            .animation({ duration: 130, curve: Curve.EaseIn })
        }
        .width('100%')
        .onClick(() => {
          // 检测器不可用（模拟器）时降级：点击蔬菜区域计一次切菜
          if (this.detectorUnavailable && this.errorMsg === '') {
            this.onGestureChop()
          }
        })

        Row({ space: ScreenUtil.w(6) }) {
          Progress({
            value: this.chopCount,
            total: this.requiredChops,
            type: ProgressType.Linear
          })
            .layoutWeight(1)
            .height(ScreenUtil.w(10))
            .color('#FFB74D')
            .borderRadius(ScreenUtil.w(5))
            .backgroundColor('#33FFFFFF')

          Text(this.progressLabel())
            .fontSize(ScreenUtil.f(14))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFE0B2')
        }
        .width('86%')
        .margin({ top: ScreenUtil.w(22) })

        if (this.permissionDenied || this.errorMsg !== '') {
          Button() {
            Text('🔪 改用手动切菜')
              .fontSize(ScreenUtil.f(14))
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .backgroundColor('#8D6E63')
          .borderRadius(ScreenUtil.w(22))
          .padding({
            left: ScreenUtil.w(24),
            right: ScreenUtil.w(24),
            top: ScreenUtil.w(10),
            bottom: ScreenUtil.w(10)
          })
          .margin({ top: ScreenUtil.w(16) })
          .onClick(() => {
            this.onClose()
          })
        }

        Row({ space: ScreenUtil.w(4) }) {
          Text('🟢')
            .fontSize(ScreenUtil.f(12))
            .opacity(this.cameraReady && this.handSeen ? 1 : 0.3)
          Text(this.statusLabel())
            .fontSize(ScreenUtil.f(12))
            .fontColor('#BDBDBD')
        }
        .margin({ top: ScreenUtil.w(14), bottom: ScreenUtil.w(18) })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1B1B1F')
  }
}
