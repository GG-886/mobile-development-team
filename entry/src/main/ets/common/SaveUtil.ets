import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'SaveUtil'
const DOMAIN = 0x0A12
const STORE_NAME = 'farm_cook_save_v2'

// 单块地存档数据
export interface PlotSave {
  state: number
  vegType: number
  watered: boolean
  remainSeconds: number
  totalSeconds: number
}

// 整体存档数据；lastSaveTs 供离线时长续算；顾客队列不入档（重进后重新上门）
export interface SaveData {
  plots: PlotSave[]
  rawCounts: number[]
  processedCounts: number[]
  coins: number
  unlockedKnife: boolean
  unlockedPlotCount: number
  guideDone: boolean
  satisfaction: number
  completedOrders: number
  readyDishes: string[]
  lastSaveTs: number
}

// 存档工具：preferences 落盘，启动读档回填
export class SaveUtil {
  private static store: preferences.Preferences | null = null

  static async init(context: Context): Promise<void> {
    if (SaveUtil.store !== null) {
      return
    }
    try {
      SaveUtil.store = await preferences.getPreferences(context, { name: STORE_NAME })
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init preferences failed')
    }
  }

  static saveAll(data: SaveData): void {
    const store = SaveUtil.store
    if (store === null) {
      return
    }
    try {
      store.putSync('plots', JSON.stringify(data.plots))
      store.putSync('rawCounts', JSON.stringify(data.rawCounts))
      store.putSync('processedCounts', JSON.stringify(data.processedCounts))
      store.putSync('coins', data.coins)
      store.putSync('unlockedKnife', data.unlockedKnife)
      store.putSync('unlockedPlotCount', data.unlockedPlotCount)
      store.putSync('guideDone', data.guideDone)
      store.putSync('satisfaction', data.satisfaction)
      store.putSync('completedOrders', data.completedOrders)
      store.putSync('readyDishes', JSON.stringify(data.readyDishes))
      store.putSync('lastSaveTs', data.lastSaveTs)
      store.flush().catch((error: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', error.message)
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveAll failed')
    }
  }

  static async loadAll(): Promise<SaveData | null> {
    const store = SaveUtil.store
    if (store === null) {
      return null
    }
    try {
      const plotsVal: preferences.ValueType = await store.get('plots', '')
      if (typeof plotsVal !== 'string' || plotsVal === '') {
        return null
      }
      const rawVal: preferences.ValueType = await store.get('rawCounts', '[0,0,0,0]')
      const proVal: preferences.ValueType = await store.get('processedCounts', '[0,0,0,0]')
      const coinsVal: preferences.ValueType = await store.get('coins', 0)
      const knifeVal: preferences.ValueType = await store.get('unlockedKnife', false)
      const plotCntVal: preferences.ValueType = await store.get('unlockedPlotCount', 6)
      const guideVal: preferences.ValueType = await store.get('guideDone', false)
      const satVal: preferences.ValueType = await store.get('satisfaction', 0)
      const compVal: preferences.ValueType = await store.get('completedOrders', 0)
      const dishesVal: preferences.ValueType = await store.get('readyDishes', '[]')
      const tsVal: preferences.ValueType = await store.get('lastSaveTs', Date.now())
      const saveData: SaveData = {
        plots: JSON.parse(plotsVal) as PlotSave[],
        rawCounts: JSON.parse(typeof rawVal === 'string' ? rawVal : '[0,0,0,0]') as number[],
        processedCounts: JSON.parse(typeof proVal === 'string' ? proVal : '[0,0,0,0]') as number[],
        coins: typeof coinsVal === 'number' ? coinsVal : 0,
        unlockedKnife: knifeVal === true,
        unlockedPlotCount: typeof plotCntVal === 'number' ? plotCntVal : 6,
        guideDone: guideVal === true,
        satisfaction: typeof satVal === 'number' ? satVal : 0,
        completedOrders: typeof compVal === 'number' ? compVal : 0,
        readyDishes: JSON.parse(typeof dishesVal === 'string' ? dishesVal : '[]') as string[],
        lastSaveTs: typeof tsVal === 'number' ? tsVal : Date.now()
      }
      return saveData
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadAll failed, treat as empty save')
      return null
    }
  }

  static clearAll(): void {
    const store = SaveUtil.store
    if (store === null) {
      return
    }
    try {
      store.clearSync()
      store.flush().catch((error: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'flush after clear failed: %{public}s', error.message)
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'clearAll failed')
    }
  }
}
