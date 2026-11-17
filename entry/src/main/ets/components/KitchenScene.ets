import { VegType, getVegInfo, RecipeInfo, PROCESSED_CAPACITY, FAST_KNIFE_PRICE } from '../game/GameModel'
import { CustomerOrder, getRecipeById, canCoverRecipe, missingIngredientLabel } from '../game/OrderModel'
import { ScreenUtil } from '../common/ScreenUtil'
import { LengthMetrics } from '@kit.ArkUI'

// 顾客订单卡：顾客头像 + 气泡订单 + 耐心条 + 缺料提示 + 交付按钮
@Component
struct CustomerCard {
  @Prop orderId: number = 0
  @Prop recipeId: string = 'salad'
  @Prop customerEmoji: string = '🧑‍🌾'
  @Prop remainSeconds: number = 60
  @Prop patienceSeconds: number = 60
  @Prop dishReady: boolean = false
  @Prop coverable: boolean = false
  @Prop missingLabel: string = ''
  onDeliver: (id: number) => void = (id: number) => {
  }

  private patienceRatio(): number {
    if (this.patienceSeconds <= 0) {
      return 0
    }
    return this.remainSeconds / this.patienceSeconds
  }

  private patienceColor(): string {
    const ratio: number = this.patienceRatio()
    if (ratio > 0.5) {
      return '#66BB6A'
    }
    if (ratio >= 0.25) {
      return '#FFA000'
    }
    return '#E53935'
  }

  private dishLabel(): string {
    const recipe: RecipeInfo = getRecipeById(this.recipeId)
    return `${recipe.emoji} ${recipe.name} ×1`
  }

  private deliverBtnColor(): string {
    if (this.dishReady) {
      return '#43A047'
    }
    if (this.coverable) {
      return '#8D6E63'
    }
    return '#BDBDBD'
  }

  build() {
    Row({ space: ScreenUtil.w(8) }) {
      Text(this.customerEmoji)
        .fontSize(ScreenUtil.f(24))

      Column({ space: ScreenUtil.w(3) }) {
        Row({ space: ScreenUtil.w(4) }) {
          Text(this.dishLabel())
            .fontSize(ScreenUtil.f(12))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.coverable ? '#33691E' : '#E65100')
            .maxLines(1)
            .layoutWeight(1)
          Text(`${this.remainSeconds}s`)
            .fontSize(ScreenUtil.f(10))
            .fontColor('#8D6E63')
        }
        .width('100%')

        Row({ space: ScreenUtil.w(5) }) {
          Progress({ value: this.remainSeconds, total: this.patienceSeconds, type: ProgressType.Linear })
            .color(this.patienceColor())
            .backgroundColor('#26000000')
            .height(ScreenUtil.w(5))
            .borderRadius(ScreenUtil.w(3))
            .layoutWeight(1)
          if (this.coverable) {
            Text('库存可做 ✓')
              .fontSize(ScreenUtil.f(9))
              .fontColor('#558B2F')
          } else {
            Text(`缺 ${this.missingLabel}`)
              .fontSize(ScreenUtil.f(9))
              .fontColor('#E53935')
              .maxLines(1)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)

      Button() {
        Text('🛎️ 交付')
          .fontSize(ScreenUtil.f(11))
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .backgroundColor(this.deliverBtnColor())
      .borderRadius(ScreenUtil.w(15))
      .padding({
        left: ScreenUtil.w(10),
        right: ScreenUtil.w(10),
        top: ScreenUtil.w(7),
        bottom: ScreenUtil.w(7)
      })
      .onClick(() => {
        this.onDeliver(this.orderId)
      })
    }
    .width('100%')
    .padding({
      left: ScreenUtil.w(10),
      right: ScreenUtil.w(8),
      top: ScreenUtil.w(7),
      bottom: ScreenUtil.w(7)
    })
    .borderRadius(ScreenUtil.w(12))
    .backgroundColor(this.dishReady ? '#E8F5E9' : '#FFFDF5')
    .border({
      width: ScreenUtil.w(1),
      color: this.dishReady ? '#66BB6A' : '#EAD9C0',
      radius: ScreenUtil.w(12)
    })
    .transition(TransitionEffect.scale({ x: 0.9, y: 0.9 })
      .combine(TransitionEffect.OPACITY)
      .animation({ duration: 180, curve: Curve.EaseOut }))
  }
}

// 厨房场景：顾客排队 + 出餐台 + 砧板切菜 + 菜谱板 + 摄像头手势切菜入口
@Component
export struct KitchenScene {
  @Prop hasBoardVeg: boolean = false
  @Prop boardVegType: VegType = VegType.CARROT
  @Prop knifeSelected: boolean = false
  @Prop isChopping: boolean = false
  @Prop boardResultEmoji: string = ''
  @Prop processedTotal: number = 0
  @Prop knifeUnlocked: boolean = false
  @Prop customers: CustomerOrder[] = []
  @Prop readyDishes: string[] = []
  @Prop rawCounts: number[] = [0, 0, 0, 0]
  @Prop processedCounts: number[] = [0, 0, 0, 0]
  @Prop cookingEmoji: string = ''
  @Prop cookingName: string = ''
  @Prop cookingRemain: number = 0
  onBoardClick: () => void = () => {
  }
  onKnifeClick: () => void = () => {
  }
  onOpenBackpack: () => void = () => {
  }
  onOpenRecipe: () => void = () => {
  }
  onUnlockKnife: () => void = () => {
  }
  onOpenGestureChop: () => void = () => {
  }
  onBackGarden: () => void = () => {
  }
  onDeliver: (id: number) => void = (id: number) => {
  }
  onDiscard: () => void = () => {
  }

  private statusHint(): string {
    if (this.isChopping) {
      return '咔嚓咔嚓…切菜中…'
    }
    if (this.hasBoardVeg && this.knifeSelected) {
      return '刀具已就绪，点击砧板上的蔬菜开切！'
    }
    if (this.hasBoardVeg) {
      return '蔬菜已就位：选刀具手动切，或开摄像头挥手切 🎥'
    }
    return '点「🎒 背包」选蔬菜放上砧板'
  }

  private knifeLabel(): string {
    if (this.knifeUnlocked) {
      if (this.knifeSelected) {
        return '✅ 快刀已选'
      }
      return '⚡ 选快刀'
    }
    if (this.knifeSelected) {
      return '✅ 刀具已选'
    }
    return '🔪 选择刀具'
  }

  private knifeBtnColor(): string {
    if (this.knifeSelected) {
      return '#6D4C41'
    }
    return '#A1887F'
  }

  private stockLabel(): string {
    return `🥘 ${this.processedTotal}/${PROCESSED_CAPACITY}`
  }

  // 顾客排队区：固定 3 个槽位，父组件每秒刷新数据
  @Builder
  CustomerQueue() {
    Column({ space: ScreenUtil.w(6) }) {
      if (this.customers.length === 0) {
        Text('🚪 门口暂时没有顾客，先切菜备菜吧～')
          .fontSize(ScreenUtil.f(11))
          .fontColor('#A1887F')
          .padding({
            left: ScreenUtil.w(12),
            right: ScreenUtil.w(12),
            top: ScreenUtil.w(9),
            bottom: ScreenUtil.w(9)
          })
          .borderRadius(ScreenUtil.w(12))
          .backgroundColor('#14A1887F')
          .border({
            width: ScreenUtil.w(1),
            color: '#D7CAB8',
            radius: ScreenUtil.w(12)
          })
      }
      if (this.customers.length > 0) {
        CustomerCard({
          orderId: this.customers[0].id,
          recipeId: this.customers[0].recipeId,
          customerEmoji: this.customers[0].emoji,
          remainSeconds: this.customers[0].remainSeconds,
          patienceSeconds: this.customers[0].patienceSeconds,
          dishReady: this.readyDishes.indexOf(this.customers[0].recipeId) >= 0,
          coverable: canCoverRecipe(this.rawCounts, this.processedCounts,
            getRecipeById(this.customers[0].recipeId)),
          missingLabel: missingIngredientLabel(this.rawCounts, this.processedCounts,
            getRecipeById(this.customers[0].recipeId)),
          onDeliver: (id: number): void => {
            this.onDeliver(id)
          }
        })
      }
      if (this.customers.length > 1) {
        CustomerCard({
          orderId: this.customers[1].id,
          recipeId: this.customers[1].recipeId,
          customerEmoji: this.customers[1].emoji,
          remainSeconds: this.customers[1].remainSeconds,
          patienceSeconds: this.customers[1].patienceSeconds,
          dishReady: this.readyDishes.indexOf(this.customers[1].recipeId) >= 0,
          coverable: canCoverRecipe(this.rawCounts, this.processedCounts,
            getRecipeById(this.customers[1].recipeId)),
          missingLabel: missingIngredientLabel(this.rawCounts, this.processedCounts,
            getRecipeById(this.customers[1].recipeId)),
          onDeliver: (id: number): void => {
            this.onDeliver(id)
          }
        })
      }
      if (this.customers.length > 2) {
        CustomerCard({
          orderId: this.customers[2].id,
          recipeId: this.customers[2].recipeId,
          customerEmoji: this.customers[2].emoji,
          remainSeconds: this.customers[2].remainSeconds,
          patienceSeconds: this.customers[2].patienceSeconds,
          dishReady: this.readyDishes.indexOf(this.customers[2].recipeId) >= 0,
          coverable: canCoverRecipe(this.rawCounts, this.processedCounts,
            getRecipeById(this.customers[2].recipeId)),
          missingLabel: missingIngredientLabel(this.rawCounts, this.processedCounts,
            getRecipeById(this.customers[2].recipeId)),
          onDeliver: (id: number): void => {
            this.onDeliver(id)
          }
        })
      }
    }
    .width('100%')
  }

  // 出餐台：烹制状态 / 成品队列 / 倒掉入口
  @Builder
  CounterBar() {
    Row({ space: ScreenUtil.w(6) }) {
      Text('🍽️ 出餐台')
        .fontSize(ScreenUtil.f(11))
        .fontColor('#6D4C41')
        .fontWeight(FontWeight.Bold)

      if (this.cookingRemain > 0) {
        Text(`${this.cookingEmoji} ${this.cookingName} 烹制中 ${this.cookingRemain}s…`)
          .fontSize(ScreenUtil.f(10))
          .fontColor('#F57C00')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .layoutWeight(1)
      } else if (this.readyDishes.length === 0) {
        Text('空空如也，去菜谱板做菜吧')
          .fontSize(ScreenUtil.f(10))
          .fontColor('#BCAAA4')
          .maxLines(1)
          .layoutWeight(1)
      } else {
        Row({ space: ScreenUtil.w(4) }) {
          Text(`${getRecipeById(this.readyDishes[0]).emoji}${getRecipeById(this.readyDishes[0]).name}`)
            .fontSize(ScreenUtil.f(10))
            .fontColor('#33691E')
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .padding({
              left: ScreenUtil.w(6),
              right: ScreenUtil.w(6),
              top: ScreenUtil.w(3),
              bottom: ScreenUtil.w(3)
            })
            .borderRadius(ScreenUtil.w(8))
            .backgroundColor('#DCEDC8')
          ForEach(this.readyDishes.slice(1, 4), (dishId: string) => {
            Text(getRecipeById(dishId).emoji)
              .fontSize(ScreenUtil.f(13))
          }, (dishId: string, idx: number): string => 'dish-' + dishId + '-' + idx)
          if (this.readyDishes.length > 4) {
            Text(`+${this.readyDishes.length - 4}`)
              .fontSize(ScreenUtil.f(10))
              .fontColor('#8D6E63')
          }
        }
        .layoutWeight(1)
      }

      if (this.readyDishes.length > 0) {
        Text('🗑️')
          .fontSize(ScreenUtil.f(14))
          .onClick(() => {
            this.onDiscard()
          })
      }
    }
    .width('100%')
    .padding({
      left: ScreenUtil.w(10),
      right: ScreenUtil.w(10),
      top: ScreenUtil.w(6),
      bottom: ScreenUtil.w(6)
    })
    .borderRadius(ScreenUtil.w(12))
    .backgroundColor('#26FFFFFF')
    .border({
      width: ScreenUtil.w(1),
      color: '#EAD9C0',
      radius: ScreenUtil.w(12)
    })
  }

  build() {
    Column({ space: ScreenUtil.w(10) }) {
      Text(this.statusHint())
        .fontSize(ScreenUtil.f(12))
        .fontColor('#795548')
        .maxLines(1)
        .textAlign(TextAlign.Center)

      this.CustomerQueue()
      this.CounterBar()

      Stack({ alignContent: Alignment.Center }) {
        Column() {
        }
        .width('88%')
        .height('80%')
        .borderRadius(ScreenUtil.w(18))
        .backgroundColor('#DEB887')
        .border({ width: ScreenUtil.w(3), color: '#A0713F', radius: ScreenUtil.w(18) })

        Column() {
        }
        .width('76%')
        .height(0)
        .border({ width: ScreenUtil.w(1), color: '#B8860B' })

        // 砧板角落：切好食材库存
        Text(this.stockLabel())
          .fontSize(ScreenUtil.f(11))
          .fontColor('#5D4037')
          .fontWeight(FontWeight.Medium)
          .position({ x: '6%', y: '2%' })
          .hitTestBehavior(HitTestMode.None)

        if (this.hasBoardVeg) {
          Text(getVegInfo(this.boardVegType).emoji)
            .fontSize(ScreenUtil.f(64))
            .rotate({ angle: this.isChopping ? -14 : 0 })
            .animation({ duration: 120, curve: Curve.EaseIn })
            .transition(TransitionEffect.scale({ x: 0.5, y: 0.5 })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 180, curve: Curve.EaseOut }))
        }

        if (this.boardResultEmoji !== '') {
          Text(`${this.boardResultEmoji} ${this.boardResultEmoji} ${this.boardResultEmoji}`)
            .fontSize(ScreenUtil.f(22))
            .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
        }

        Text('🔪')
          .fontSize(ScreenUtil.f(46))
          .position({ x: '64%', y: '-8%' })
          .translate({ y: this.isChopping ? ScreenUtil.w(78) : 0 })
          .rotate({ angle: this.isChopping ? 28 : -8 })
          .animation({ duration: 130, curve: Curve.EaseIn })

        if (this.isChopping) {
          Text('✨').fontSize(ScreenUtil.f(26))
            .position({ x: '20%', y: '20%' })
            .transition(TransitionEffect.OPACITY)
          Text('✨').fontSize(ScreenUtil.f(20))
            .position({ x: '76%', y: '30%' })
            .transition(TransitionEffect.OPACITY)
        }
      }
      .width('100%')
      .aspectRatio(2.2)
      .onClick(() => {
        this.onBoardClick()
      })

      if (this.hasBoardVeg) {
        Button() {
          Text('🎥 开摄像头，挥手切菜')
            .fontSize(ScreenUtil.f(13))
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .backgroundColor('#7E57C2')
        .borderRadius(ScreenUtil.w(22))
        .constraintSize({ maxWidth: '94%' })
        .padding({
          left: ScreenUtil.w(18),
          right: ScreenUtil.w(18),
          top: ScreenUtil.w(9),
          bottom: ScreenUtil.w(9)
        })
        .onClick(() => {
          this.onOpenGestureChop()
        })
      }

      if (!this.knifeUnlocked) {
        Button() {
          Text(`⚡ 解锁快刀 ${FAST_KNIFE_PRICE}💰 · 切菜提速近一倍`)
            .fontSize(ScreenUtil.f(12))
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .backgroundColor('#F57C00')
        .borderRadius(ScreenUtil.w(22))
        .constraintSize({ maxWidth: '94%' })
        .padding({
          left: ScreenUtil.w(16),
          right: ScreenUtil.w(16),
          top: ScreenUtil.w(8),
          bottom: ScreenUtil.w(8)
        })
        .onClick(() => {
          this.onUnlockKnife()
        })
      }

      // 底部操作按钮：Flex 换行布局，窄屏自动折成两行，宽屏单行铺满
      Flex({
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.Center,
        alignContent: FlexAlign.Center,
        space: {
          main: LengthMetrics.vp(ScreenUtil.w(8)),
          cross: LengthMetrics.vp(ScreenUtil.w(8))
        }
      }) {
        Button() {
          Text(this.knifeLabel())
            .fontSize(ScreenUtil.f(13))
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .backgroundColor(this.knifeBtnColor())
        .borderRadius(ScreenUtil.w(22))
        .flexGrow(1)
        .padding({
          left: ScreenUtil.w(13),
          right: ScreenUtil.w(13),
          top: ScreenUtil.w(9),
          bottom: ScreenUtil.w(9)
        })
        .onClick(() => {
          this.onKnifeClick()
        })

        Button() {
          Text('🎒 背包')
            .fontSize(ScreenUtil.f(13))
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .backgroundColor('#8D6E63')
        .borderRadius(ScreenUtil.w(22))
        .flexGrow(1)
        .padding({
          left: ScreenUtil.w(13),
          right: ScreenUtil.w(13),
          top: ScreenUtil.w(9),
          bottom: ScreenUtil.w(9)
        })
        .onClick(() => {
          this.onOpenBackpack()
        })

        Button() {
          Text('📖 菜谱板')
            .fontSize(ScreenUtil.f(13))
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .backgroundColor('#66BB6A')
        .borderRadius(ScreenUtil.w(22))
        .flexGrow(1)
        .padding({
          left: ScreenUtil.w(13),
          right: ScreenUtil.w(13),
          top: ScreenUtil.w(9),
          bottom: ScreenUtil.w(9)
        })
        .onClick(() => {
          this.onOpenRecipe()
        })

        Button() {
          Text('🏡 返回菜园')
            .fontSize(ScreenUtil.f(13))
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .backgroundColor('#6D4C41')
        .borderRadius(ScreenUtil.w(22))
        .flexGrow(1)
        .padding({
          left: ScreenUtil.w(13),
          right: ScreenUtil.w(13),
          top: ScreenUtil.w(9),
          bottom: ScreenUtil.w(9)
        })
        .onClick(() => {
          this.onBackGarden()
        })
      }
      .width('100%')
      .margin({ bottom: ScreenUtil.w(8) })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
