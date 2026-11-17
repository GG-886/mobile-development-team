// 蔬菜类型
export enum VegType {
  CARROT = 0,
  GREENS = 1,
  POTATO = 2,
  TOMATO = 3
}

// 场景类型
export enum SceneKind {
  GARDEN = 0,
  KITCHEN = 1
}

// 地块状态
export enum PlotState {
  EMPTY = 0,
  SEEDED = 1,
  GROWING = 2,
  MATURE = 3
}

// 蔬菜静态配置
export class VegInfo {
  readonly type: VegType
  readonly name: string
  readonly emoji: string
  readonly growSeconds: number
  readonly processedName: string
  readonly processedEmoji: string
  readonly themeColor: string
  // 整菜直售价（金币）
  readonly price: number

  constructor(type: VegType, name: string, emoji: string, growSeconds: number,
    processedName: string, processedEmoji: string, themeColor: string, price: number) {
    this.type = type
    this.name = name
    this.emoji = emoji
    this.growSeconds = growSeconds
    this.processedName = processedName
    this.processedEmoji = processedEmoji
    this.themeColor = themeColor
    this.price = price
  }
}

// 四种蔬菜：胡萝卜最快，土豆最慢；直售价 胡萝卜8 / 青菜10 / 番茄10 / 土豆16
export const VEG_INFO_LIST: VegInfo[] = [
  new VegInfo(VegType.CARROT, '胡萝卜', '🥕', 20, '萝卜片', '🟠', '#FFE0B2', 8),
  new VegInfo(VegType.GREENS, '青菜', '🥬', 30, '青菜段', '🟢', '#DCEDC8', 10),
  new VegInfo(VegType.TOMATO, '番茄', '🍅', 30, '番茄块', '🔴', '#FFCDD2', 10),
  new VegInfo(VegType.POTATO, '土豆', '🥔', 45, '土豆块', '🟤', '#EFEBE9', 16)
]

export function getVegInfo(type: VegType): VegInfo {
  const found: VegInfo | undefined =
    VEG_INFO_LIST.find((item: VegInfo): boolean => item.type === type)
  if (found === undefined) {
    return VEG_INFO_LIST[0]
  }
  return found
}

// 原始蔬菜背包容量上限
export const RAW_BAG_CAPACITY: number = 8

// 切好食材库存上限
export const PROCESSED_CAPACITY: number = 12

// 手势切菜需要完成的挥刀次数
export const CHOPS_REQUIRED: number = 3

// 快刀解锁价（金币），解锁后切菜 900ms → 500ms
export const FAST_KNIFE_PRICE: number = 80

// 第 7、8 块地解锁价（金币）
export const UNLOCK_PLOT_PRICES: number[] = [50, 100]

// 菜谱原料配比
export interface RecipeIngredient {
  type: VegType
  count: number
}

// 菜谱静态配置：出锅后放上出餐台，交付顾客换取金币与小费
export interface RecipeInfo {
  id: string
  name: string
  emoji: string
  inputs: RecipeIngredient[]
  price: number
  cookSeconds: number
  // 解锁所需累计完成订单数（0 = 初始解锁）
  unlockOrders: number
}

export const RECIPE_LIST: RecipeInfo[] = [
  {
    id: 'salad',
    name: '蔬菜沙拉',
    emoji: '🥗',
    inputs: [{ type: VegType.CARROT, count: 1 }, { type: VegType.GREENS, count: 1 }],
    price: 28,
    cookSeconds: 5,
    unlockOrders: 0
  },
  {
    id: 'soup',
    name: '番茄汤',
    emoji: '🍲',
    inputs: [{ type: VegType.TOMATO, count: 2 }],
    price: 24,
    cookSeconds: 5,
    unlockOrders: 0
  },
  {
    id: 'stew',
    name: '土豆炖菜',
    emoji: '🥘',
    inputs: [{ type: VegType.POTATO, count: 1 }, { type: VegType.GREENS, count: 1 }],
    price: 34,
    cookSeconds: 8,
    unlockOrders: 10
  }
]

// 地块数据（@Observed 供 PlotCell @ObjectLink 逐格刷新）
@Observed
export class Plot {
  id: number
  state: PlotState
  vegType: VegType
  watered: boolean
  remainSeconds: number
  totalSeconds: number

  constructor(id: number) {
    this.id = id
    this.state = PlotState.EMPTY
    this.vegType = VegType.CARROT
    this.watered = false
    this.remainSeconds = 0
    this.totalSeconds = 0
  }
}
