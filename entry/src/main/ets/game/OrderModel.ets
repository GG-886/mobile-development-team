import { RecipeInfo, RECIPE_LIST, getVegInfo } from './GameModel'

// 顾客同时排队上限
export const ORDER_QUEUE_MAX: number = 3
// 顾客耐心总时长（秒）
export const PATIENCE_SECONDS: number = 60
// 顾客上门间隔区间（秒）
export const SPAWN_MIN_SECONDS: number = 14
export const SPAWN_MAX_SECONDS: number = 24
// 首位顾客上门延迟（秒）：首次有收成后开始倒计时
export const FIRST_SPAWN_DELAY: number = 6

// 铺子等级阈值：累计完成订单数（Lv2 = 10 单，Lv3 = 25 单）
export const SHOP_LV2_ORDERS: number = 10
export const SHOP_LV3_ORDERS: number = 25

// 顾客头像池
export const CUSTOMER_EMOJI_LIST: string[] = [
  '🧑‍🌾', '👩‍🎨', '🧓', '👦', '👧', '👨‍💼', '👩‍🎓', '🧕', '👴', '👱‍♀️'
]

// 顾客订单（纯数据类，供排队渲染与交付判定）
export class CustomerOrder {
  id: number
  recipeId: string
  emoji: string
  patienceSeconds: number
  remainSeconds: number

  constructor(id: number, recipeId: string, emoji: string, patienceSeconds: number, remainSeconds: number) {
    this.id = id
    this.recipeId = recipeId
    this.emoji = emoji
    this.patienceSeconds = patienceSeconds
    this.remainSeconds = remainSeconds
  }
}

// 小费系数：按交付时剩余耐心分档（> 一半 0.30 / 1/4 ~ 1/2 0.15 / 其余 0）
export function tipRateOf(remainSeconds: number, patienceSeconds: number): number {
  if (patienceSeconds <= 0) {
    return 0
  }
  const ratio: number = remainSeconds / patienceSeconds
  if (ratio > 0.5) {
    return 0.3
  }
  if (ratio >= 0.25) {
    return 0.15
  }
  return 0
}

export function shopLevelOf(completedOrders: number): number {
  if (completedOrders >= SHOP_LV3_ORDERS) {
    return 3
  }
  if (completedOrders >= SHOP_LV2_ORDERS) {
    return 2
  }
  return 1
}

export function shopLevelLabel(level: number): string {
  if (level >= 3) {
    return 'Lv3 小餐馆'
  }
  if (level === 2) {
    return 'Lv2 小菜铺'
  }
  return 'Lv1 路边小摊'
}

export function getRecipeById(id: string): RecipeInfo {
  const found: RecipeInfo | undefined = RECIPE_LIST.find((item: RecipeInfo): boolean => item.id === id)
  if (found === undefined) {
    return RECIPE_LIST[0]
  }
  return found
}

export function isRecipeUnlocked(recipe: RecipeInfo, completedOrders: number): boolean {
  return completedOrders >= recipe.unlockOrders
}

// 库存（食材 + 整菜）能否覆盖菜谱需求
export function canCoverRecipe(rawCounts: number[], processedCounts: number[], recipe: RecipeInfo): boolean {
  for (const need of recipe.inputs) {
    if (processedCounts[need.type] + rawCounts[need.type] < need.count) {
      return false
    }
  }
  return true
}

// 缺料文案：如「萝卜片×1、青菜段×1」
export function missingIngredientLabel(rawCounts: number[], processedCounts: number[], recipe: RecipeInfo): string {
  const parts: string[] = []
  for (const need of recipe.inputs) {
    const have: number = processedCounts[need.type] + rawCounts[need.type]
    if (have < need.count) {
      parts.push(`${getVegInfo(need.type).processedName}×${need.count - have}`)
    }
  }
  return parts.join('、')
}

export function randomSpawnSeconds(): number {
  return SPAWN_MIN_SECONDS + Math.floor(Math.random() * (SPAWN_MAX_SECONDS - SPAWN_MIN_SECONDS + 1))
}

export function randomCustomerEmoji(): string {
  const index: number = Math.floor(Math.random() * CUSTOMER_EMOJI_LIST.length)
  return CUSTOMER_EMOJI_LIST[index]
}
