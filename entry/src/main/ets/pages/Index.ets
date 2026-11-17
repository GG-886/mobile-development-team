import {
  Plot,
  PlotState,
  SceneKind,
  VegType,
  RAW_BAG_CAPACITY,
  PROCESSED_CAPACITY,
  CHOPS_REQUIRED,
  FAST_KNIFE_PRICE,
  UNLOCK_PLOT_PRICES,
  RECIPE_LIST,
  RecipeInfo,
  getVegInfo
} from '../game/GameModel'
import {
  CustomerOrder,
  ORDER_QUEUE_MAX,
  PATIENCE_SECONDS,
  FIRST_SPAWN_DELAY,
  tipRateOf,
  shopLevelOf,
  shopLevelLabel,
  getRecipeById,
  isRecipeUnlocked,
  canCoverRecipe,
  randomSpawnSeconds,
  randomCustomerEmoji
} from '../game/OrderModel'
import { SaveUtil, SaveData, PlotSave } from '../common/SaveUtil'
import { ScreenUtil } from '../common/ScreenUtil'
import { GardenScene } from '../components/GardenScene'
import { KitchenScene } from '../components/KitchenScene'
import { BackpackDialog } from '../components/BackpackDialog'
import { SeedSelectDialog } from '../components/SeedSelectDialog'
import { OneClickDialog } from '../components/OneClickDialog'
import { RecipeDialog } from '../components/RecipeDialog'
import { GestureChopOverlay } from '../components/GestureChopOverlay'

// 游戏主控制器：菜园 ↔ 厨房 + 顾客订单闭环（接单-做菜-交付-小费满意度）+ 存档
@Entry
@Component
struct Index {
  @State plots: Plot[] = [
    new Plot(0), new Plot(1), new Plot(2),
    new Plot(3), new Plot(4), new Plot(5)
  ]
  @State currentScene: SceneKind = SceneKind.GARDEN
  @State selectedPlotId: number = -1
  @State wateringPlotId: number = -1
  @State seedDialogPlotId: number = -1
  @State showBackpack: boolean = false
  @State showOneClick: boolean = false
  @State showRecipe: boolean = false
  @State lastSeedType: VegType = VegType.CARROT
  @State rawCounts: number[] = [0, 0, 0, 0]
  @State processedCounts: number[] = [0, 0, 0, 0]
  @State hasBoardVeg: boolean = false
  @State boardVegType: VegType = VegType.CARROT
  @State boardResultEmoji: string = ''
  @State knifeSelected: boolean = false
  @State isChopping: boolean = false
  @State toastMsg: string = ''
  @State gestureChopActive: boolean = false
  @State coins: number = 0
  @State unlockedPlotCount: number = 6
  @State unlockedKnife: boolean = false
  @State firstRunGuide: boolean = false
  // 顾客订单闭环状态
  @State customers: CustomerOrder[] = []
  @State readyDishes: string[] = []
  @State cookingRecipeId: string = ''
  @State cookingRemainSeconds: number = 0
  @State satisfaction: number = 0
  @State completedOrders: number = 0
  @State shopLevel: number = 1

  private tickTimerId: number = -1
  private toastTimerId: number = -1
  private waterAnimTimerId: number = -1
  private chopTimerId: number = -1
  private chopResultTimerId: number = -1
  private nextCustomerId: number = 1
  // 顾客上门倒计时（秒）；-1 表示等待首批收成后启动
  private customerSpawnCountdown: number = -1

  aboutToAppear(): void {
    this.initSave()
    this.tickTimerId = setInterval(() => {
      this.tickGrowth()
      this.tickCooking()
      this.tickCustomers()
    }, 1000)
  }

  // 初始化存档并读档：preferences 读为异步，回填后状态自动刷新
  private async initSave(): Promise<void> {
    const ctx: Context | undefined = this.getUIContext().getHostContext()
    if (ctx !== undefined) {
      await SaveUtil.init(ctx)
    }
    const saved: SaveData | null = await SaveUtil.loadAll()
    if (saved !== null) {
      this.coins = saved.coins
      this.unlockedKnife = saved.unlockedKnife
      this.satisfaction = saved.satisfaction
      this.completedOrders = saved.completedOrders
      this.shopLevel = shopLevelOf(this.completedOrders)
      this.rawCounts = this.normalizeCounts(saved.rawCounts)
      this.processedCounts = this.normalizeCounts(saved.processedCounts)
      this.readyDishes = this.normalizeDishes(saved.readyDishes)
      this.restorePlots(saved)
      this.firstRunGuide = !saved.guideDone
    } else {
      this.firstRunGuide = true
    }
    if (this.firstRunGuide) {
      this.showToast('点击空地选择种子，开始你的田园生活吧 🌱')
    }
  }

  aboutToDisappear(): void {
    this.persist()
    clearInterval(this.tickTimerId)
    clearTimeout(this.toastTimerId)
    clearTimeout(this.waterAnimTimerId)
    clearTimeout(this.chopTimerId)
    clearTimeout(this.chopResultTimerId)
  }

  // ---------- 存档 ----------

  private normalizeCounts(counts: number[]): number[] {
    const result: number[] = [0, 0, 0, 0]
    for (let i = 0; i < 4; i++) {
      if (i < counts.length && counts[i] > 0) {
        result[i] = Math.floor(counts[i])
      }
    }
    return result
  }

  // 出餐台菜品只保留已知菜谱 id，上限 12 份
  private normalizeDishes(dishes: string[]): string[] {
    const result: string[] = []
    for (const dishId of dishes) {
      const known: boolean = RECIPE_LIST.some((item: RecipeInfo): boolean => item.id === dishId)
      if (known && result.length < 12) {
        result.push(dishId)
      }
    }
    return result
  }

  private normalizePlotState(state: number): PlotState {
    if (state === PlotState.SEEDED || state === PlotState.GROWING || state === PlotState.MATURE) {
      return state
    }
    return PlotState.EMPTY
  }

  private normalizeVegType(vegType: number): VegType {
    if (vegType === VegType.GREENS || vegType === VegType.POTATO || vegType === VegType.TOMATO) {
      return vegType
    }
    return VegType.CARROT
  }

  // 读档回填地块；按 lastSaveTs 差值续算离线生长
  private restorePlots(saved: SaveData): void {
    const restored: Plot[] = []
    const elapsedSec: number = Math.max(0, Math.floor((Date.now() - saved.lastSaveTs) / 1000))
    const count: number = Math.min(saved.plots.length, Math.max(saved.unlockedPlotCount, 6))
    for (let i = 0; i < count; i++) {
      const ps: PlotSave = saved.plots[i]
      const plotItem: Plot = new Plot(i)
      plotItem.state = this.normalizePlotState(ps.state)
      plotItem.vegType = this.normalizeVegType(ps.vegType)
      plotItem.watered = ps.watered
      plotItem.totalSeconds = Math.max(0, ps.totalSeconds)
      plotItem.remainSeconds = Math.max(0, ps.remainSeconds)
      if (plotItem.state === PlotState.GROWING && elapsedSec > 0) {
        plotItem.remainSeconds -= elapsedSec
        if (plotItem.remainSeconds <= 0) {
          plotItem.remainSeconds = 0
          plotItem.state = PlotState.MATURE
        }
      }
      restored.push(plotItem)
    }
    this.plots = restored
    this.unlockedPlotCount = restored.length
  }

  private buildSaveData(): SaveData {
    const plotSaves: PlotSave[] = []
    for (const plotItem of this.plots) {
      const ps: PlotSave = {
        state: plotItem.state,
        vegType: plotItem.vegType,
        watered: plotItem.watered,
        remainSeconds: plotItem.remainSeconds,
        totalSeconds: plotItem.totalSeconds
      }
      plotSaves.push(ps)
    }
    // 烹制中的菜在落盘时视为已完成，避免离线丢失
    const dishes: string[] = this.readyDishes.slice()
    if (this.cookingRecipeId !== '') {
      dishes.push(this.cookingRecipeId)
    }
    const saveData: SaveData = {
      plots: plotSaves,
      rawCounts: this.rawCounts.slice(),
      processedCounts: this.processedCounts.slice(),
      coins: this.coins,
      unlockedKnife: this.unlockedKnife,
      unlockedPlotCount: this.unlockedPlotCount,
      guideDone: !this.firstRunGuide,
      satisfaction: this.satisfaction,
      completedOrders: this.completedOrders,
      readyDishes: dishes,
      lastSaveTs: Date.now()
    }
    return saveData
  }

  private persist(): void {
    SaveUtil.saveAll(this.buildSaveData())
  }

  // ---------- 每秒心跳 ----------

  private tickGrowth(): void {
    for (let i = 0; i < this.plots.length; i++) {
      const plotItem: Plot = this.plots[i]
      if (plotItem.state === PlotState.GROWING && plotItem.watered && plotItem.remainSeconds > 0) {
        plotItem.remainSeconds -= 1
        if (plotItem.remainSeconds <= 0) {
          plotItem.state = PlotState.MATURE
          this.showToast(`${getVegInfo(plotItem.vegType).name}成熟啦！快去收获 ✨`)
        }
      }
    }
  }

  // 烹制计时：完成后菜品放上出餐台
  private tickCooking(): void {
    if (this.cookingRemainSeconds <= 0) {
      return
    }
    this.cookingRemainSeconds -= 1
    if (this.cookingRemainSeconds <= 0) {
      const recipe: RecipeInfo = getRecipeById(this.cookingRecipeId)
      this.readyDishes.push(recipe.id)
      this.cookingRecipeId = ''
      this.cookingRemainSeconds = 0
      this.persist()
      this.showToast(`${recipe.name}出锅！已放上出餐台 🍽️ 快交付给顾客吧`)
    }
  }

  // 顾客耐心倒计时 + 上门生成
  private tickCustomers(): void {
    if (this.customers.length > 0) {
      const next: CustomerOrder[] = []
      let someoneLeft: boolean = false
      for (const customer of this.customers) {
        const remain: number = customer.remainSeconds - 1
        if (remain <= 0) {
          someoneLeft = true
          this.satisfaction -= 1
        } else {
          next.push(new CustomerOrder(customer.id, customer.recipeId, customer.emoji,
            customer.patienceSeconds, remain))
        }
      }
      this.customers = next
      if (someoneLeft) {
        this.persist()
        this.showToast('有顾客等不及走掉了… 😞 满意度 -1')
      }
    }
    // 首批收成后启动上门倒计时
    if (this.customerSpawnCountdown < 0) {
      if (this.totalRawCount() + this.processedTotal() + this.readyDishes.length > 0) {
        this.customerSpawnCountdown = FIRST_SPAWN_DELAY
      }
      return
    }
    if (this.customers.length >= ORDER_QUEUE_MAX) {
      return
    }
    this.customerSpawnCountdown -= 1
    if (this.customerSpawnCountdown <= 0) {
      this.spawnCustomer()
      this.customerSpawnCountdown = randomSpawnSeconds()
    }
  }

  // 生成上门顾客：首单必出库存可覆盖的菜品；后续 70% 倾向可覆盖菜品
  private spawnCustomer(): void {
    const unlocked: RecipeInfo[] =
      RECIPE_LIST.filter((item: RecipeInfo): boolean => isRecipeUnlocked(item, this.completedOrders))
    if (unlocked.length === 0) {
      return
    }
    const coverable: RecipeInfo[] =
      unlocked.filter((item: RecipeInfo): boolean => canCoverRecipe(this.rawCounts, this.processedCounts, item))
    let picked: RecipeInfo
    if (coverable.length > 0) {
      if (this.completedOrders === 0 || Math.random() < 0.7) {
        picked = coverable[Math.floor(Math.random() * coverable.length)]
      } else {
        picked = unlocked[Math.floor(Math.random() * unlocked.length)]
      }
    } else if (this.completedOrders === 0) {
      // 首单必须可覆盖：暂不上门，稍后重试
      this.customerSpawnCountdown = 5
      return
    } else {
      picked = unlocked[Math.floor(Math.random() * unlocked.length)]
    }
    const customer: CustomerOrder =
      new CustomerOrder(this.nextCustomerId, picked.id, randomCustomerEmoji(), PATIENCE_SECONDS, PATIENCE_SECONDS)
    this.nextCustomerId += 1
    this.customers.push(customer)
    this.showToast(`${customer.emoji} 顾客上门：想要一份「${picked.name}」${picked.emoji}`)
  }

  private showToast(message: string): void {
    this.toastMsg = message
    clearTimeout(this.toastTimerId)
    this.toastTimerId = setTimeout(() => {
      this.toastMsg = ''
    }, 1800)
  }

  private totalRawCount(): number {
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

  private sceneLabel(): string {
    if (this.currentScene === SceneKind.GARDEN) {
      return '菜园 · 播种养护'
    }
    return `厨房 · ${shopLevelLabel(this.shopLevel)}`
  }

  private bagLabel(): string {
    return `🎒 ${this.totalRawCount()}`
  }

  // ---------- 菜园逻辑 ----------

  private onPlotClick(id: number): void {
    const plotItem: Plot = this.plots[id]
    if (plotItem.state === PlotState.EMPTY) {
      this.seedDialogPlotId = id
      return
    }
    if (plotItem.state === PlotState.SEEDED) {
      this.selectedPlotId = id
      this.showToast('已选中地块，点击「💧 浇水」开始种植')
      return
    }
    if (plotItem.state === PlotState.GROWING) {
      this.selectedPlotId = id
      this.showToast(`${getVegInfo(plotItem.vegType).name}生长中，还需 ${plotItem.remainSeconds} 秒`)
      return
    }
    this.harvest(id)
  }

  private harvest(id: number): void {
    const plotItem: Plot = this.plots[id]
    if (this.totalRawCount() >= RAW_BAG_CAPACITY) {
      this.showToast(`背包已满（${RAW_BAG_CAPACITY} 个），先去厨房切菜吧！`)
      return
    }
    const info = getVegInfo(plotItem.vegType)
    this.rawCounts[plotItem.vegType] += 1
    plotItem.state = PlotState.EMPTY
    plotItem.watered = false
    plotItem.remainSeconds = 0
    plotItem.totalSeconds = 0
    this.selectedPlotId = -1
    this.persist()
    this.showToast(`收获成功！${info.name} ×1 已入背包 🎒`)
  }

  private onSeedPick(type: VegType): void {
    if (this.seedDialogPlotId < 0) {
      return
    }
    this.lastSeedType = type
    const plotItem: Plot = this.plots[this.seedDialogPlotId]
    const info = getVegInfo(type)
    plotItem.vegType = type
    plotItem.state = PlotState.SEEDED
    plotItem.watered = false
    plotItem.totalSeconds = info.growSeconds
    plotItem.remainSeconds = info.growSeconds
    this.seedDialogPlotId = -1
    this.selectedPlotId = plotItem.id
    this.firstRunGuide = false
    this.persist()
    this.showToast(`播种成功：${info.name} 🌰 选中地块点「浇水」`)
  }

  private waterSelected(): void {
    if (this.selectedPlotId < 0) {
      this.showToast('先点击一块「已播种」的地块')
      return
    }
    const plotItem: Plot = this.plots[this.selectedPlotId]
    if (plotItem.state !== PlotState.SEEDED) {
      this.showToast('这块地现在不需要浇水哦')
      return
    }
    plotItem.watered = true
    plotItem.state = PlotState.GROWING
    plotItem.remainSeconds = plotItem.totalSeconds
    this.wateringPlotId = plotItem.id
    clearTimeout(this.waterAnimTimerId)
    this.waterAnimTimerId = setTimeout(() => {
      this.wateringPlotId = -1
    }, 1200)
    this.persist()
    this.showToast('浇水完成，作物开始生长 💧')
  }

  // ---------- 一键工作逻辑 ----------

  private emptyPlotCount(): number {
    let count: number = 0
    for (const plotItem of this.plots) {
      if (plotItem.state === PlotState.EMPTY) {
        count += 1
      }
    }
    return count
  }

  private seededPlotCount(): number {
    let count: number = 0
    for (const plotItem of this.plots) {
      if (plotItem.state === PlotState.SEEDED) {
        count += 1
      }
    }
    return count
  }

  private oneClickSow(seedType: VegType): void {
    this.lastSeedType = seedType
    const seedInfo = getVegInfo(seedType)
    let count: number = 0
    for (const plotItem of this.plots) {
      if (plotItem.state === PlotState.EMPTY) {
        plotItem.vegType = seedType
        plotItem.state = PlotState.SEEDED
        plotItem.watered = false
        plotItem.totalSeconds = seedInfo.growSeconds
        plotItem.remainSeconds = seedInfo.growSeconds
        count += 1
      }
    }
    this.showOneClick = false
    if (count === 0) {
      this.showToast('没有空地可以播种啦')
      return
    }
    this.firstRunGuide = false
    this.persist()
    this.showToast(`一键播种完成：${count} 块空地种上了${seedInfo.name} 🌰 记得浇水`)
  }

  private oneClickWater(): void {
    let count: number = 0
    for (const plotItem of this.plots) {
      if (plotItem.state === PlotState.SEEDED) {
        plotItem.watered = true
        plotItem.state = PlotState.GROWING
        plotItem.remainSeconds = plotItem.totalSeconds
        count += 1
      }
    }
    this.showOneClick = false
    if (count === 0) {
      this.showToast('没有待浇水的地块')
      return
    }
    this.persist()
    this.showToast(`一键浇水完成：${count} 块地开始生长 💧`)
  }

  // ---------- 地块解锁 ----------

  private unlockPlot(): void {
    if (this.unlockedPlotCount >= 8) {
      return
    }
    const priceIndex: number = this.unlockedPlotCount - 6
    const price: number = UNLOCK_PLOT_PRICES[priceIndex]
    if (this.coins < price) {
      this.showToast(`金币不足，还差 ${price - this.coins} 金币解锁新地块`)
      return
    }
    this.coins -= price
    this.plots.push(new Plot(this.unlockedPlotCount))
    this.unlockedPlotCount += 1
    this.persist()
    this.showToast(`第 ${this.unlockedPlotCount} 块地解锁成功！快去播种吧 🌱`)
  }

  // ---------- 厨房逻辑 ----------

  private onRawVegClick(type: VegType): void {
    if (this.isChopping) {
      return
    }
    if (this.rawCounts[type] <= 0) {
      this.showToast('还没有这种蔬菜，去菜园种一些吧')
      return
    }
    if (this.hasBoardVeg) {
      this.showToast('砧板上已有蔬菜，先切完这一份')
      return
    }
    this.rawCounts[type] -= 1
    this.boardVegType = type
    this.hasBoardVeg = true
    this.knifeSelected = false
    this.showBackpack = false
    this.persist()
    this.showToast(`${getVegInfo(type).name}已放上砧板，点「🔪 选择刀具」`)
  }

  private onKnifeClick(): void {
    if (this.isChopping) {
      return
    }
    this.knifeSelected = !this.knifeSelected
    if (this.knifeSelected && this.hasBoardVeg) {
      this.showToast('刀具已就绪，点击砧板上的蔬菜开切！')
    }
  }

  private onBoardClick(): void {
    if (this.isChopping) {
      return
    }
    if (!this.hasBoardVeg) {
      this.showToast('砧板空空的，点「🎒 背包」选蔬菜')
      return
    }
    if (!this.knifeSelected) {
      this.showToast('请先点「🔪 选择刀具」拿起刀')
      return
    }
    this.startChop()
  }

  private startChop(): void {
    if (this.processedTotal() >= PROCESSED_CAPACITY) {
      this.showToast(`食材已达上限（${PROCESSED_CAPACITY}），先去做菜交付订单吧`)
      return
    }
    const choppingType: VegType = this.boardVegType
    // 快刀解锁后切菜 900ms → 500ms
    const chopMs: number = this.unlockedKnife ? 500 : 900
    this.isChopping = true
    clearTimeout(this.chopTimerId)
    this.chopTimerId = setTimeout(() => {
      this.processedCounts[choppingType] += 1
      this.hasBoardVeg = false
      this.isChopping = false
      this.knifeSelected = false
      this.boardResultEmoji = getVegInfo(choppingType).processedEmoji
      clearTimeout(this.chopResultTimerId)
      this.chopResultTimerId = setTimeout(() => {
        this.boardResultEmoji = ''
      }, 700)
      this.persist()
      this.showToast(`切菜完成！${getVegInfo(choppingType).processedName} ×1 🎉`)
    }, chopMs)
  }

  // ---------- 手势切菜逻辑 ----------

  private onOpenGestureChop(): void {
    if (this.isChopping) {
      return
    }
    if (this.processedTotal() >= PROCESSED_CAPACITY) {
      this.showToast(`食材已达上限（${PROCESSED_CAPACITY}），先去做菜交付订单吧`)
      return
    }
    if (!this.hasBoardVeg) {
      this.showToast('砧板上还没有蔬菜，点「🎒 背包」选一些')
      return
    }
    this.gestureChopActive = true
  }

  private onGestureChopProgress(count: number): void {
    if (count < CHOPS_REQUIRED) {
      return
    }
    const choppedType: VegType = this.boardVegType
    this.processedCounts[choppedType] += 1
    this.hasBoardVeg = false
    this.isChopping = false
    this.knifeSelected = false
    this.gestureChopActive = false
    this.boardResultEmoji = getVegInfo(choppedType).processedEmoji
    clearTimeout(this.chopResultTimerId)
    this.chopResultTimerId = setTimeout(() => {
      this.boardResultEmoji = ''
    }, 700)
    this.persist()
    this.showToast(`手势切菜完成！${getVegInfo(choppedType).processedName} ×1 🎉`)
  }

  // ---------- 菜谱与订单闭环 ----------

  private canCook(recipe: RecipeInfo): boolean {
    for (const need of recipe.inputs) {
      if (this.processedCounts[need.type] < need.count) {
        return false
      }
    }
    return true
  }

  // 做菜：消耗食材 → 烹制计时 → 出餐台，等待顾客交付
  private cookRecipe(recipe: RecipeInfo): void {
    if (this.cookingRemainSeconds > 0) {
      this.showToast('厨房正在烹制中，稍等一下～')
      return
    }
    if (!isRecipeUnlocked(recipe, this.completedOrders)) {
      this.showToast('这道菜还没解锁哦')
      return
    }
    if (!this.canCook(recipe)) {
      this.showToast('食材不足，先去切菜备料吧')
      return
    }
    for (const need of recipe.inputs) {
      this.processedCounts[need.type] -= need.count
    }
    this.cookingRecipeId = recipe.id
    this.cookingRemainSeconds = recipe.cookSeconds
    this.showRecipe = false
    this.persist()
    this.showToast(`开始烹制${recipe.name}，请稍候… 👨‍🍳`)
  }

  // 交付判定：出餐台有对应菜品 → 成功（基础价 + 按剩余耐心小费）；送错菜 → 拒收损失食材
  private deliverTo(customerId: number): void {
    const customer: CustomerOrder | undefined =
      this.customers.find((item: CustomerOrder): boolean => item.id === customerId)
    if (customer === undefined) {
      return
    }
    const wanted: RecipeInfo = getRecipeById(customer.recipeId)
    if (this.readyDishes.length === 0) {
      this.showToast(`出餐台还没有菜，先去「📖 菜谱板」做${wanted.name}吧`)
      return
    }
    const matchIndex: number = this.readyDishes.indexOf(wanted.id)
    if (matchIndex >= 0) {
      this.readyDishes.splice(matchIndex, 1)
      this.finishDelivery(customer, wanted)
      return
    }
    // 出餐台只有别的菜：提示送错会被拒收
    const front: RecipeInfo = getRecipeById(this.readyDishes[0])
    this.getUIContext().showAlertDialog({
      title: '送错菜了？',
      message: `出餐台上是「${front.name}」，这位顾客要的是「${wanted.name}」。坚持送出会被拒收，这份菜就浪费了哦。`,
      primaryButton: {
        value: '再想想',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '坚持送出',
        action: (): void => {
          this.readyDishes.splice(0, 1)
          this.satisfaction -= 1
          this.persist()
          this.showToast(`顾客摇头拒绝了「${front.name}」… 满意度 -1 😞`)
        }
      }
    })
  }

  private finishDelivery(customer: CustomerOrder, wanted: RecipeInfo): void {
    const rate: number = tipRateOf(customer.remainSeconds, customer.patienceSeconds)
    const tip: number = Math.round(wanted.price * rate)
    const prevCompleted: number = this.completedOrders
    this.coins += wanted.price + tip
    this.completedOrders += 1
    this.satisfaction += 1
    this.customers = this.customers.filter((item: CustomerOrder): boolean => item.id !== customer.id)
    this.checkLevelUp(prevCompleted)
    this.persist()
    if (tip > 0) {
      this.showToast(`交付成功！${wanted.emoji} ${wanted.name} +${wanted.price}💰 小费 +${tip}💰 😄`)
    } else {
      this.showToast(`交付成功！${wanted.emoji} ${wanted.name} +${wanted.price}💰 😊`)
    }
  }

  // 铺子等级：完成 10 单 → Lv2（解锁土豆炖菜）；25 单 → Lv3
  private checkLevelUp(prevCompleted: number): void {
    const prevLevel: number = shopLevelOf(prevCompleted)
    const newLevel: number = shopLevelOf(this.completedOrders)
    if (newLevel > prevLevel) {
      this.shopLevel = newLevel
      if (newLevel === 2) {
        this.showToast('🎉 铺子升级：Lv2 小菜铺！新菜谱「🥘 土豆炖菜」已解锁')
      } else {
        this.showToast('🎉 铺子升级：Lv3 小餐馆！生意兴隆～')
      }
    }
  }

  // 倒掉出餐台最前一份菜（不退款）
  private discardReadyDish(): void {
    if (this.readyDishes.length === 0) {
      return
    }
    const front: RecipeInfo = getRecipeById(this.readyDishes[0])
    this.getUIContext().showAlertDialog({
      title: '倒掉这份菜？',
      message: `「${front.name}」会被倒掉，不会退款。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '倒掉',
        action: (): void => {
          this.readyDishes.splice(0, 1)
          this.persist()
          this.showToast('菜已倒掉 🗑️')
        }
      }
    })
  }

  private sellRaw(type: VegType): void {
    if (this.rawCounts[type] <= 0) {
      return
    }
    this.rawCounts[type] -= 1
    const price: number = getVegInfo(type).price
    this.coins += price
    this.persist()
    this.showToast(`直售${getVegInfo(type).name}，金币 +${price} 💰`)
  }

  private unlockKnife(): void {
    if (this.unlockedKnife) {
      return
    }
    if (this.coins < FAST_KNIFE_PRICE) {
      this.showToast(`金币不足，还差 ${FAST_KNIFE_PRICE - this.coins} 金币解锁快刀`)
      return
    }
    this.coins -= FAST_KNIFE_PRICE
    this.unlockedKnife = true
    this.persist()
    this.showToast('快刀解锁成功！切菜速度大幅提升 ⚡')
  }

  // ---------- 场景切换 ----------

  private switchScene(): void {
    if (this.currentScene === SceneKind.GARDEN) {
      this.currentScene = SceneKind.KITCHEN
    } else {
      this.currentScene = SceneKind.GARDEN
    }
    this.showBackpack = false
    this.showRecipe = false
    this.selectedPlotId = -1
  }

  @Builder
  TitleBar() {
    Row() {
      Column({ space: ScreenUtil.w(2) }) {
        Text('🏡 田园小菜铺')
          .fontSize(ScreenUtil.f(20))
          .fontWeight(FontWeight.Bold)
          .fontColor('#3E2723')
        Text(this.sceneLabel())
          .fontSize(ScreenUtil.f(12))
          .fontColor('#6D4C41')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`😊 ${this.satisfaction}`)
        .fontSize(ScreenUtil.f(14))
        .fontColor('#5D4037')
        .fontWeight(FontWeight.Medium)
        .margin({ right: ScreenUtil.w(10) })

      Text(`💰 ${this.coins}`)
        .fontSize(ScreenUtil.f(15))
        .fontColor('#F57F17')
        .fontWeight(FontWeight.Bold)
        .margin({ right: ScreenUtil.w(10) })

      Button() {
        Text(this.bagLabel())
          .fontSize(ScreenUtil.f(15))
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .backgroundColor('#8D6E63')
      .borderRadius(ScreenUtil.w(20))
      .padding({
        left: ScreenUtil.w(14),
        right: ScreenUtil.w(14),
        top: ScreenUtil.w(7),
        bottom: ScreenUtil.w(7)
      })
      .onClick(() => {
        this.showBackpack = true
      })
    }
    .width('100%')
    .padding({
      left: ScreenUtil.w(18),
      right: ScreenUtil.w(18),
      top: ScreenUtil.w(14),
      bottom: ScreenUtil.w(6)
    })
  }

  @Builder
  ToastOverlay() {
    Column() {
      Text(this.toastMsg)
        .fontSize(ScreenUtil.f(14))
        .fontColor('#FFFFFF')
        .backgroundColor('#CC2B1D0F')
        .borderRadius(ScreenUtil.w(20))
        .padding({
          left: ScreenUtil.w(18),
          right: ScreenUtil.w(18),
          top: ScreenUtil.w(10),
          bottom: ScreenUtil.w(10)
        })
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: ScreenUtil.w(120) })
    .hitTestBehavior(HitTestMode.None)
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }

  @Builder
  GardenView() {
    Column() {
      GardenScene({
        plots: this.plots,
        selectedPlotId: this.selectedPlotId,
        wateringPlotId: this.wateringPlotId,
        unlockedPlotCount: this.unlockedPlotCount,
        guideActive: this.firstRunGuide,
        onPlotClick: (id: number): void => {
          this.onPlotClick(id)
        },
        onWaterClick: (): void => {
          this.waterSelected()
        },
        onGoKitchen: (): void => {
          this.switchScene()
        },
        onOneClickWork: (): void => {
          this.showOneClick = true
        },
        onUnlockPlot: (): void => {
          this.unlockPlot()
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
  }

  @Builder
  KitchenView() {
    Column() {
      KitchenScene({
        hasBoardVeg: this.hasBoardVeg,
        boardVegType: this.boardVegType,
        knifeSelected: this.knifeSelected,
        isChopping: this.isChopping,
        boardResultEmoji: this.boardResultEmoji,
        processedTotal: this.processedTotal(),
        knifeUnlocked: this.unlockedKnife,
        customers: this.customers,
        readyDishes: this.readyDishes,
        rawCounts: this.rawCounts,
        processedCounts: this.processedCounts,
        cookingEmoji: this.cookingRecipeId !== '' ? getRecipeById(this.cookingRecipeId).emoji : '',
        cookingName: this.cookingRecipeId !== '' ? getRecipeById(this.cookingRecipeId).name : '',
        cookingRemain: this.cookingRemainSeconds,
        onBoardClick: (): void => {
          this.onBoardClick()
        },
        onKnifeClick: (): void => {
          this.onKnifeClick()
        },
        onOpenBackpack: (): void => {
          this.showBackpack = true
        },
        onOpenRecipe: (): void => {
          this.showRecipe = true
        },
        onUnlockKnife: (): void => {
          this.unlockKnife()
        },
        onOpenGestureChop: (): void => {
          this.onOpenGestureChop()
        },
        onBackGarden: (): void => {
          this.switchScene()
        },
        onDeliver: (id: number): void => {
          this.deliverTo(id)
        },
        onDiscard: (): void => {
          this.discardReadyDish()
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
  }

  build() {
    Stack() {
      if (this.currentScene === SceneKind.GARDEN) {
        Column() {
        }
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#A8DCEA', 0.0], ['#D9EFCB', 1.0]]
        })
      } else {
        Column() {
        }
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#FFE9C4', 0.0], ['#FFD9BC', 1.0]]
        })
      }

      Column() {
        this.TitleBar()
        if (this.currentScene === SceneKind.GARDEN) {
          this.GardenView()
        } else {
          this.KitchenView()
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: ScreenUtil.w(430) })

      if (this.toastMsg !== '') {
        this.ToastOverlay()
      }

      if (this.showBackpack) {
        BackpackDialog({
          rawCounts: this.rawCounts,
          processedCounts: this.processedCounts,
          isKitchenMode: this.currentScene === SceneKind.KITCHEN,
          onRawVegClick: (type: VegType): void => {
            this.onRawVegClick(type)
          },
          onJumpRecipe: (): void => {
            this.showBackpack = false
            this.showRecipe = true
          },
          onClose: (): void => {
            this.showBackpack = false
          }
        })
      }

      if (this.showOneClick) {
        OneClickDialog({
          emptyCount: this.emptyPlotCount(),
          seededCount: this.seededPlotCount(),
          selectedSeed: this.lastSeedType,
          onSow: (type: VegType): void => {
            this.oneClickSow(type)
          },
          onWater: (): void => {
            this.oneClickWater()
          },
          onClose: (): void => {
            this.showOneClick = false
          }
        })
      }

      if (this.showRecipe) {
        RecipeDialog({
          rawCounts: this.rawCounts,
          processedCounts: this.processedCounts,
          coins: this.coins,
          completedOrders: this.completedOrders,
          cookingActive: this.cookingRemainSeconds > 0,
          onCook: (recipe: RecipeInfo): void => {
            this.cookRecipe(recipe)
          },
          onSellRaw: (type: VegType): void => {
            this.sellRaw(type)
          },
          onClose: (): void => {
            this.showRecipe = false
          }
        })
      }

      if (this.seedDialogPlotId >= 0) {
        SeedSelectDialog({
          onSeedPick: (type: VegType): void => {
            this.onSeedPick(type)
          },
          onClose: (): void => {
            this.seedDialogPlotId = -1
          }
        })
      }

      if (this.gestureChopActive) {
        GestureChopOverlay({
          vegEmoji: getVegInfo(this.boardVegType).emoji,
          requiredChops: CHOPS_REQUIRED,
          onChop: (count: number): void => {
            this.onGestureChopProgress(count)
          },
          onClose: (): void => {
            this.gestureChopActive = false
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
