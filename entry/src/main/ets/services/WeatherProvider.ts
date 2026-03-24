import { DailyForecast, HourlyForecast, LifeIndex, MinuteRainPoint, WeatherState } from '../model/WeatherState';

export interface WeatherProvider {
  /**
   * @param locationQuery 传给和风 weather 的 location：城市 ID（Geo 返回）或内置表可解析的名称
   * @param displayCityName 首页/状态栏展示用名称（与 location 可不同，如「长沙县」）
   */
  getWeather(locationQuery: string, displayCityName: string): Promise<{
    currentTemperature: number;
    currentConditionText: string;
    hourly: HourlyForecast[];
    daily: DailyForecast[];
    lifeIndex: LifeIndex;
    minuteRain: MinuteRainPoint[];
    lastUpdatedText: string;
    cityName: string;
  }>;
}

export function applyProviderDataToState(
  // 把 provider 的原始数据写入 WeatherState（phase1/phase2 数据写入点）
  state: WeatherState,
  data: {
    currentTemperature: number;
    currentConditionText: string;
    hourly: HourlyForecast[];
    daily: DailyForecast[];
    lifeIndex: LifeIndex;
    minuteRain: MinuteRainPoint[];
    lastUpdatedText: string;
    cityName: string;
  }
): WeatherState {
  // 成功写入后，把状态切换到 success（由页面决定显示内容）
  state.status = 'success';
  state.cityName = data.cityName;
  state.currentTemperature = data.currentTemperature;
  state.currentConditionText = data.currentConditionText;
  state.hourly = data.hourly;
  state.daily = data.daily;
  state.lifeIndex = data.lifeIndex;
  state.minuteRain = data.minuteRain;
  state.lastUpdatedText = data.lastUpdatedText;
  state.errorMessage = undefined;
  return state;
}

