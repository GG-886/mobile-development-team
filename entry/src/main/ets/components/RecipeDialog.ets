import { ScreenUtil } from '../common/ScreenUtil'
import {
  VegType,
  VEG_INFO_LIST,
  VegInfo,
  RECIPE_LIST,
  RecipeInfo,
  RecipeIngredient,
  getVegInfo
} from '../game/GameModel'

// 菜谱板：食材组合做菜放上出餐台（交付顾客赚金币+小费）+ 整菜直售兜底
@Component
export struct RecipeDialog {
  @Prop processedCounts: number[] = [0, 0, 0, 0]
  @Prop rawCounts: number[] = [0, 0, 0, 0]
  @Prop coins: number = 0
  @Prop completedOrders: number = 0
  @Prop cookingActive: boolean = false
  onCook: (recipe: RecipeInfo) => void = (recipe: RecipeInfo) => {
  }
  onSellRaw: (type: VegType) => void = (type: VegType) => {
  }
  onClose: () => void = () => {
  }

  private isLocked(recipe: RecipeInfo): boolean {
    return this.completedOrders < recipe.unlockOrders
  }

  private canCook(recipe: RecipeInfo): boolean {
    for (const need of recipe.inputs) {
      if (this.processedCounts[need.type] < need.count) {
        return false
      }
    }
    return true
  }

  private ingredientLabel(recipe: RecipeInfo): string {
    let label: string = ''
    for (let i = 0; i < recipe.inputs.length; i++) {
      const need: RecipeIngredient = recipe.inputs[i]
      if (i > 0) {
        label += ' + '
      }
      label += `${getVegInfo(need.type).processedName}×${need.count}`
    }
    return label
  }

  private rowEnabled(recipe: RecipeInfo): boolean {
    return !this.isLocked(recipe) && !this.cookingActive && this.canCook(recipe)
  }

  @Builder
  RecipeRow(recipe: RecipeInfo) {
    Row({ space: ScreenUtil.w(10) }) {
      Text(this.isLocked(recipe) ? '🔒' : recipe.emoji)
        .fontSize(ScreenUtil.f(26))
      Column({ space: ScreenUtil.w(2) }) {
        Text(recipe.name)
          .fontSize(ScreenUtil.f(14))
          .fontColor('#3E2723')
          .fontWeight(FontWeight.Medium)
        if (this.isLocked(recipe)) {
          Text(`完成 ${recipe.unlockOrders} 单解锁`)
            .fontSize(ScreenUtil.f(10))
            .fontColor('#F57C00')
        } else {
          Text(this.ingredientLabel(recipe))
            .fontSize(ScreenUtil.f(10))
            .fontColor('#8D6E63')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: ScreenUtil.w(1) }) {
        if (this.isLocked(recipe)) {
          Text('未解锁')
            .fontSize(ScreenUtil.f(11))
            .fontColor('#BCAAA4')
        } else if (this.cookingActive) {
          Text('👨‍🍳 烹制中')
            .fontSize(ScreenUtil.f(11))
            .fontColor('#F57C00')
        } else {
          Text(`${recipe.price}💰 + 小费`)
            .fontSize(ScreenUtil.f(13))
            .fontColor('#5D4037')
            .fontWeight(FontWeight.Bold)
          Text(`${recipe.cookSeconds}s`)
            .fontSize(ScreenUtil.f(9))
            .fontColor('#A1887F')
        }
      }
    }
    .width('100%')
    .padding(ScreenUtil.w(12))
    .borderRadius(ScreenUtil.w(14))
    .backgroundColor(this.rowEnabled(recipe) ? '#E8F5E9' : '#14000000')
    .opacity(this.rowEnabled(recipe) ? 1 : 0.55)
    .onClick(() => {
      if (this.rowEnabled(recipe)) {
        this.onCook(recipe)
      }
    })
  }

  @Builder
  RawSellRow(veg: VegInfo) {
    Row({ space: ScreenUtil.w(8) }) {
      Text(veg.emoji)
        .fontSize(ScreenUtil.f(18))
      Text(veg.name)
        .fontSize(ScreenUtil.f(12))
        .fontColor('#3E2723')
      Text(`×${this.rawCounts[veg.type]}`)
        .fontSize(ScreenUtil.f(12))
        .fontColor('#8D6E63')
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(`直售 +${veg.price}💰`)
        .fontSize(ScreenUtil.f(11))
        .fontColor('#5D4037')
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .padding({
      left: ScreenUtil.w(12),
      right: ScreenUtil.w(12),
      top: ScreenUtil.w(8),
      bottom: ScreenUtil.w(8)
    })
    .borderRadius(ScreenUtil.w(12))
    .backgroundColor(this.rawCounts[veg.type] > 0 ? '#FFF3E0' : '#14000000')
    .opacity(this.rawCounts[veg.type] > 0 ? 1 : 0.55)
    .onClick(() => {
      if (this.rawCounts[veg.type] > 0) {
        this.onSellRaw(veg.type)
      }
    })
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

      Column({ space: ScreenUtil.w(12) }) {
        Row() {
          Text('📖 菜谱板')
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

        Text(`💰 金币：${this.coins} · 😊 满意度随交付累计`)
          .fontSize(ScreenUtil.f(13))
          .fontColor('#5D4037')
          .fontWeight(FontWeight.Bold)

        ForEach(RECIPE_LIST, (recipe: RecipeInfo) => {
          this.RecipeRow(recipe)
        }, (recipe: RecipeInfo): string => 'recipe-' + recipe.id)

        Divider()
          .color('#E0D5C8')
          .width('100%')

        Text('🥕 整菜直售兜底（接单做菜更划算）')
          .fontSize(ScreenUtil.f(12))
          .fontColor('#8D6E63')
          .fontWeight(FontWeight.Bold)
          .width('100%')

        ForEach(VEG_INFO_LIST, (veg: VegInfo) => {
          this.RawSellRow(veg)
        }, (veg: VegInfo): string => 'sell-' + veg.type)

        Text('出锅的菜放上出餐台，点顾客订单卡「🛎️ 交付」得金币和小费；出餐越快小费越多 💰')
          .fontSize(ScreenUtil.f(10))
          .fontColor('#A1887F')
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
