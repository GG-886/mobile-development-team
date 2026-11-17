import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { skeletonDetection, visionBase } from '@kit.CoreVisionKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'ChopCameraController'
const DOMAIN = 0x0A10
// 骨骼点检测节流间隔，控制功耗与 CPU 占用
const DETECT_INTERVAL_MS = 240
// 手腕关键点置信度阈值
const WRIST_SCORE_THRESHOLD = 0.3

// 摄像头手势识别控制器：双路预览（XComponent 显示 + ImageReceiver 供 AI）+ 骨骼点检测追踪手腕
export class ChopCameraController {
  private camManager: camera.CameraManager | null = null
  private camInput: camera.CameraInput | null = null
  private displayOutput: camera.PreviewOutput | null = null
  private aiOutput: camera.PreviewOutput | null = null
  private session: camera.PhotoSession | null = null
  private receiver: image.ImageReceiver | null = null
  private detector: skeletonDetection.SkeletonDetector | null = null
  private frameW: number = 0
  private frameH: number = 0
  private srcFormat: image.PixelMapFormat = image.PixelMapFormat.NV21
  private lastDetectMs: number = 0
  private detecting: boolean = false
  private releasing: boolean = false
  private started: boolean = false
  // 检测到手腕时回调，yNorm 为画面纵向归一化坐标（0 顶部，1 底部）
  onWristDetected: (yNorm: number) => void = () => {
  }
  // 相机会话启动成功回调
  onReady: () => void = () => {
  }
  // 致命错误回调（相机占用/不支持等），msg 为用户可读描述
  onError: (msg: string) => void = () => {
  }
  // 骨骼检测不可用回调（如模拟器无 AI 模型），相机预览仍可用，由上层降级交互
  onDetectorUnavailable: () => void = () => {
  }

  async start(context: Context, displaySurfaceId: string): Promise<void> {
    if (this.started) {
      return
    }
    this.started = true
    try {
      this.camManager = camera.getCameraManager(context)
      const cams: Array<camera.CameraDevice> = this.camManager.getSupportedCameras()
      if (cams.length === 0) {
        await this.fail('当前设备没有可用摄像头')
        return
      }
      let device: camera.CameraDevice = cams[0]
      for (const cam of cams) {
        if (cam.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
          device = cam
          break
        }
      }
      this.camInput = this.camManager.createCameraInput(device)
      await this.camInput.open()
      const capability: camera.CameraOutputCapability =
        this.camManager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO)
      const profiles: Array<camera.Profile> = capability.previewProfiles
      if (profiles.length === 0) {
        await this.fail('当前设备不支持相机预览')
        return
      }
      const displayProfile: camera.Profile = this.pickDisplayProfile(profiles)
      const aiProfile: camera.Profile | null = this.pickAiProfile(profiles)
      if (aiProfile === null) {
        await this.fail('当前设备不支持手势识别所需的预览格式')
        return
      }
      this.frameW = aiProfile.size.width
      this.frameH = aiProfile.size.height
      this.srcFormat = aiProfile.format === camera.CameraFormat.CAMERA_FORMAT_RGBA_8888 ?
      image.PixelMapFormat.RGBA_8888 : image.PixelMapFormat.NV21
      this.receiver = image.createImageReceiver(
        { width: this.frameW, height: this.frameH },
        image.ImageFormat.JPEG,
        5
      )
      const receiverSurfaceId: string = await this.receiver.getReceivingSurfaceId()
      this.receiver.on('imageArrival', () => {
        this.onFrameArrival()
      })
      this.displayOutput = this.camManager.createPreviewOutput(displayProfile, displaySurfaceId)
      this.aiOutput = this.camManager.createPreviewOutput(aiProfile, receiverSurfaceId)
      this.session =
        this.camManager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO)
      this.session.beginConfig()
      this.session.addInput(this.camInput)
      this.session.addOutput(this.displayOutput)
      this.session.addOutput(this.aiOutput)
      await this.session.commitConfig()
      await this.session.start()
      try {
        this.detector = await skeletonDetection.SkeletonDetector.create()
      } catch (err) {
        // 模拟器等设备无骨骼检测模型，降级为仅预览，不视为相机启动失败
        const error = err as BusinessError
        hilog.warn(DOMAIN, TAG, 'skeleton detector unavailable, code %{public}d, msg %{public}s',
          error.code, error.message)
        this.detector = null
      }
      hilog.info(DOMAIN, TAG, 'camera gesture session started, ai frame %{public}d x %{public}d',
        this.frameW, this.frameH)
      this.onReady()
      if (this.detector === null) {
        this.onDetectorUnavailable()
      }
    } catch (err) {
      const error = err as BusinessError
      hilog.error(DOMAIN, TAG, 'start failed, code %{public}d, msg %{public}s',
        error.code, error.message)
      await this.fail('摄像头启动失败，请稍后重试')
    }
  }

  async stop(): Promise<void> {
    this.releasing = true
    if (this.detector !== null) {
      try {
        await this.detector.destroy()
      } catch (err) {
        const error = err as BusinessError
        hilog.warn(DOMAIN, TAG, 'detector destroy failed: %{public}s', error.message)
      }
      this.detector = null
    }
    if (this.session !== null) {
      try {
        await this.session.stop()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'session stop failed')
      }
      try {
        await this.session.release()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'session release failed')
      }
      this.session = null
    }
    if (this.displayOutput !== null) {
      try {
        await this.displayOutput.release()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'displayOutput release failed')
      }
      this.displayOutput = null
    }
    if (this.aiOutput !== null) {
      try {
        await this.aiOutput.release()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'aiOutput release failed')
      }
      this.aiOutput = null
    }
    if (this.camInput !== null) {
      try {
        await this.camInput.close()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'cameraInput close failed')
      }
      this.camInput = null
    }
    if (this.receiver !== null) {
      try {
        await this.receiver.release()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'receiver release failed')
      }
      this.receiver = null
    }
    this.camManager = null
    // 复位帧回调门控，保证后续 start() 重试时能正常消费帧
    this.releasing = false
    this.detecting = false
  }

  // 失败统一处理：回滚已申请的相机资源并复位 started，允许用户重试
  private async fail(msg: string): Promise<void> {
    await this.stop()
    this.started = false
    this.onError(msg)
  }

  private pickDisplayProfile(profiles: Array<camera.Profile>): camera.Profile {
    // 显示流优先选择宽高较大的一档，保证预览清晰度
    let best: camera.Profile = profiles[0]
    let bestArea: number = 0
    for (const profile of profiles) {
      const area: number = profile.size.width * profile.size.height
      if (area > bestArea) {
        bestArea = area
        best = profile
      }
    }
    return best
  }

  private pickAiProfile(profiles: Array<camera.Profile>): camera.Profile | null {
    // 算法流优先 RGBA 格式、分辨率最小的一档，降低每帧 AI 处理开销
    let best: camera.Profile | null = null
    let bestArea: number = Number.MAX_VALUE
    for (const profile of profiles) {
      const supported: boolean = profile.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP ||
        profile.format === camera.CameraFormat.CAMERA_FORMAT_RGBA_8888
      if (!supported) {
        continue
      }
      const isRgba: boolean = profile.format === camera.CameraFormat.CAMERA_FORMAT_RGBA_8888
      const area: number = profile.size.width * profile.size.height
      if (best === null) {
        best = profile
        bestArea = area
        continue
      }
      const bestIsRgba: boolean =
        best.format === camera.CameraFormat.CAMERA_FORMAT_RGBA_8888
      if ((isRgba && !bestIsRgba) || (isRgba === bestIsRgba && area < bestArea)) {
        best = profile
        bestArea = area
      }
    }
    return best
  }

  private onFrameArrival(): void {
    const receiver = this.receiver
    if (receiver === null || this.releasing || this.detecting || this.detector === null) {
      return
    }
    const now: number = Date.now()
    if (now - this.lastDetectMs < DETECT_INTERVAL_MS) {
      return
    }
    receiver.readLatestImage((err: BusinessError, img: image.Image) => {
      if (err || img === undefined) {
        return
      }
      this.lastDetectMs = Date.now()
      this.detecting = true
      this.processFrame(img)
    })
  }

  private async processFrame(img: image.Image): Promise<void> {
    try {
      const component: image.Component = await img.getComponent(image.ComponentType.JPEG)
      // rowStride 为字节单位，需按源格式每像素字节数换算为像素宽度，否则 createPixelMap 越界读导致崩溃
      const bytesPerPixel: number = this.srcFormat === image.PixelMapFormat.RGBA_8888 ? 4 : 1
      const stride: number = component.rowStride
      const stridePx: number = bytesPerPixel > 0 ? Math.floor(stride / bytesPerPixel) : this.frameW
      const createWidth: number = stridePx > 0 ? stridePx : this.frameW
      const expectedBytes: number = this.srcFormat === image.PixelMapFormat.RGBA_8888 ?
        createWidth * this.frameH * 4 : Math.floor(createWidth * this.frameH * 3 / 2)
      if (createWidth <= 0 || this.frameH <= 0 || component.byteBuffer.byteLength < expectedBytes) {
        hilog.warn(DOMAIN, TAG,
          'skip frame, buffer %{public}d bytes < expected %{public}d, size %{public}d x %{public}d',
          component.byteBuffer.byteLength, expectedBytes, createWidth, this.frameH)
        await img.release()
        this.detecting = false
        return
      }
      const strideDifferent: boolean = createWidth !== this.frameW
      const options: image.InitializationOptions = {
        size: { width: createWidth, height: this.frameH },
        srcPixelFormat: this.srcFormat,
        pixelFormat: image.PixelMapFormat.RGBA_8888
      }
      const pixelMap: image.PixelMap = await image.createPixelMap(component.byteBuffer, options)
      if (strideDifferent) {
        pixelMap.applyCropSync({ x: 0, y: 0, size: { width: this.frameW, height: this.frameH } })
      }
      await img.release()
      await this.detectSkeleton(pixelMap)
    } catch (err) {
      const error = err as BusinessError
      hilog.error(DOMAIN, TAG, 'process frame failed, code %{public}d, msg %{public}s',
        error.code, error.message)
      this.detecting = false
    }
  }

  private async detectSkeleton(pixelMap: image.PixelMap): Promise<void> {
    const detector = this.detector
    if (detector === null) {
      this.detecting = false
      try {
        await pixelMap.release()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'pixelMap release failed')
      }
      return
    }
    try {
      const imageData: visionBase.ImageData = { pixelMap: pixelMap }
      const request: visionBase.Request = new visionBase.Request()
      request.inputData = imageData
      const response: skeletonDetection.SkeletonDetectionResponse = await detector.process(request)
      this.handleSkeletonResponse(response)
    } catch (err) {
      const error = err as BusinessError
      hilog.error(DOMAIN, TAG, 'skeleton detect failed, code %{public}d, msg %{public}s',
        error.code, error.message)
    } finally {
      this.detecting = false
      try {
        await pixelMap.release()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'pixelMap release after detect failed')
      }
    }
  }

  private handleSkeletonResponse(response: skeletonDetection.SkeletonDetectionResponse): void {
    let bestY: number = -1
    let bestScore: number = 0
    for (const skeleton of response.skeletons) {
      for (const point of skeleton.points) {
        const isWrist: boolean = point.type === skeletonDetection.SkeletonPointType.LEFT_WRIST ||
          point.type === skeletonDetection.SkeletonPointType.RIGHT_WRIST
        if (isWrist && point.score > bestScore) {
          bestScore = point.score
          bestY = point.point.y
        }
      }
    }
    if (bestScore >= WRIST_SCORE_THRESHOLD && bestY >= 0 && this.frameH > 0) {
      let yNorm: number = bestY / this.frameH
      if (yNorm < 0) {
        yNorm = 0
      }
      if (yNorm > 1) {
        yNorm = 1
      }
      this.onWristDetected(yNorm)
    }
  }
}
