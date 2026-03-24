// 天气加载状态：由 ViewModel/provider 决定，页面用于显示不同占位态
export type WeatherStatus = 'loading' | 'success' | 'error' | 'offline';

export interface HourlyForecast {
  hourLabel: string; // e.g. "13:00"
  temperature: number;
  conditionText: string;
  precipitationProbability: number; // 0-100
}

export interface DailyForecast {
  dateLabel: string; // e.g. "Mon"
  highTemperature: number;
  lowTemperature: number;
  conditionText: string;
}

export interface LifeIndex {
  dressing: string; // 穿衣建议
  uvIndex: number;
  uvDesc: string;
  airQualityText: string;
}

export interface MinuteRainPoint {
  minuteLabel: string; // e.g. "14:20"
  intensity: number; // 0-100
}

export class WeatherState {
  // 当前加载状态
  status: WeatherStatus = 'loading';
  // 当前城市名
  cityName: string = '—';

  // 当前温度（摄氏度）
  currentTemperature: number = 0;
  // 当前天气描述
  currentConditionText: string = '—';

  // 逐小时预报（24 小时）
  hourly: HourlyForecast[] = [];
  // 7 天预报
  daily: DailyForecast[] = [];
  // 生活指数
  lifeIndex: LifeIndex | undefined;
  // 分钟级降水热力时间轴（分钟点）
  minuteRain: MinuteRainPoint[] = [];

  // 数据更新时间文本
  lastUpdatedText: string = '';

  // 错误信息（用于 error/offline 占位态）
  errorMessage: string | undefined;

  static empty(): WeatherState {
    return new WeatherState();
  }
}

