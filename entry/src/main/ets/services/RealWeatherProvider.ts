import { http } from '@kit.NetworkKit';
import type { WeatherProvider } from './WeatherProvider';
import type { DailyForecast, HourlyForecast, LifeIndex, MinuteRainPoint } from '../model/WeatherState';
import { MockWeatherProvider } from './MockWeatherProvider';
import { WEATHER_API_CONFIG, isWeatherAuthConfigured, resolveCityLocationId } from './WeatherApiConfig';

function httpGet(url: string, headers: Record<string, string>): Promise<{ statusCode: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.createHttp();
    req.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 30000,
        readTimeout: 30000,
        expectDataType: http.HttpDataType.STRING
      },
      (err, data) => {
        if (err) {
          req.destroy();
          reject(err);
          return;
        }
        const statusCode = data.responseCode;
        const raw = data.result;
        const body = typeof raw === 'string' ? raw : '';
        req.destroy();
        resolve({ statusCode, body });
      }
    );
  });
}

type NormalizedWeatherData = {
  currentTemperature: number;
  currentConditionText: string;
  hourly: HourlyForecast[];
  daily: DailyForecast[];
  lifeIndex: LifeIndex;
  minuteRain: MinuteRainPoint[];
  lastUpdatedText: string;
  cityName: string;
};

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function formatTimeFromISO(iso: string): string {
  // 和风时间通常为 yyyy-MM-dd'T'HH:mmZ 或 yyyy-MM-dd HH:mm
  const normalized = iso.includes('T') ? iso : iso.replace(' ', 'T');
  const d = new Date(normalized);
  if (isNaN(d.getTime())) return '';
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function formatDayFromISO(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const week = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return week[d.getDay()];
}

function codeToCondition(code: number): string {
  // 兜底用：和风代码按大类转中文描述
  if (code === 100) return '晴';
  if (code >= 101 && code <= 104) return '多云';
  if (code >= 300 && code <= 313) return '雨';
  if (code >= 400 && code <= 407) return '雪';
  if (code >= 500 && code <= 515) return '雾霾';
  return '阴';
}

function buildLifeIndexFromCurrent(conditionText: string): LifeIndex {
  // 和风返回中文天气描述，这里用关键字粗略推断生活指数
  const rainy = conditionText.includes('雨');
  const sunny = conditionText.includes('晴');
  const baseUv = sunny ? 8 : 5;
  return {
    dressing: rainy ? '适当加雨具' : '穿衣适中',
    uvIndex: baseUv,
    uvDesc: baseUv >= 7 ? '注意防晒' : '可正常活动',
    airQualityText: rainy ? '空气一般' : '空气良好'
  };
}

export class RealWeatherProvider implements WeatherProvider {
  private static cache?: { timestamp: number; data: NormalizedWeatherData };
  private static cacheTtlMs = 10 * 60 * 1000; // 10 minutes

  private backupProvider: WeatherProvider = new MockWeatherProvider();

  async getWeather(locationQuery: string, displayCityName: string): Promise<NormalizedWeatherData> {
    // 和风接口按 location 查询（城市ID/经纬度）
    const location = resolveCityLocationId(locationQuery);
    if (!location) {
      throw new Error('location_failed');
    }
    if (!isWeatherAuthConfigured()) {
      throw new Error('token_missing');
    }

    try {
      // 并行请求：实时、24小时、7天
      const [nowResp, h24Resp, d7Resp] = await Promise.all([
        this.fetchQWeather<QNowResponse>('/v7/weather/now', location),
        this.fetchQWeather<Q24hResponse>('/v7/weather/24h', location),
        this.fetchQWeather<Q7dResponse>('/v7/weather/7d', location)
      ]);

      const label = displayCityName.trim().length > 0 ? displayCityName.trim() : locationQuery;
      const normalized = this.normalizeQWeatherResponse(label, nowResp, h24Resp, d7Resp);
      if (!normalized.hourly.length || !normalized.daily.length) {
        throw new Error('empty response');
      }

      RealWeatherProvider.cache = {
        timestamp: Date.now(),
        data: normalized
      };
      return normalized;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);

      // 失败先回退缓存
      const cache = RealWeatherProvider.cache;
      if (cache && Date.now() - cache.timestamp <= RealWeatherProvider.cacheTtlMs) {
        return cache.data;
      }

      // token 缺失或 location 失败：不回退 mock，直接提示配置/城市
      if (msg === 'token_missing' || msg === 'location_failed') {
        throw new Error(msg);
      }

      // 其他失败回退 mock，保证页面可用
      try {
        return await this.backupProvider.getWeather(locationQuery, displayCityName);
      } catch {
        // mock 也失败时再抛统一错误
      }

      const strictOffline = msg.startsWith('http_') || msg.includes('network');
      if (strictOffline) {
        throw new Error('offline');
      }

      throw new Error(msg || 'Real API error');
    }
  }

  private async fetchQWeather<T extends QWeatherResponseBase>(
    path: string,
    location: string
  ): Promise<T> {
    const base = `${WEATHER_API_CONFIG.host}${path}?location=${encodeURIComponent(location)}&lang=${WEATHER_API_CONFIG.lang}&unit=${WEATHER_API_CONFIG.unit}`;
    const url =
      WEATHER_API_CONFIG.apiKey.length > 0
        ? `${base}&key=${encodeURIComponent(WEATHER_API_CONFIG.apiKey)}`
        : base;

    const headers: Record<string, string> = {};
    if (WEATHER_API_CONFIG.apiKey.length === 0 && WEATHER_API_CONFIG.bearerToken.length > 0) {
      headers['Authorization'] = `Bearer ${WEATHER_API_CONFIG.bearerToken}`;
    }

    let text: string;
    try {
      const resp = await httpGet(url, headers);
      if (resp.statusCode !== 200) {
        if (resp.statusCode === 401 || resp.statusCode === 403) {
          throw new Error('token_expired');
        }
        throw new Error(`http_${resp.statusCode}`);
      }
      text = resp.body;
    } catch {
      throw new Error('network');
    }

    const parsed = JSON.parse(text) as T & QWeatherResponseBase;
    if (parsed.code !== '200') {
      if (parsed.code === '401' || parsed.code === '402') {
        throw new Error('token_expired');
      }
      throw new Error(`api_${parsed.code}`);
    }
    return parsed as T;
  }

  private normalizeQWeatherResponse(
    cityName: string,
    nowResp: QNowResponse,
    h24Resp: Q24hResponse,
    d7Resp: Q7dResponse
  ): NormalizedWeatherData {
    const now = nowResp.now;
    const currentTemp = Number(now.temp ?? 0);
    const currentConditionText = now.text || codeToCondition(Number(now.icon ?? 0));

    const hourly: HourlyForecast[] = [];
    const h24 = h24Resp.hourly ?? [];
    for (let i = 0; i < Math.min(24, h24.length); i++) {
      const item = h24[i];
      hourly.push({
        hourLabel: formatTimeFromISO(item.fxTime) || `+${i}h`,
        temperature: Number(item.temp ?? 0),
        conditionText: item.text || codeToCondition(Number(item.icon ?? 0)),
        precipitationProbability: Math.round(Number(item.pop ?? 0))
      });
    }

    const daily: DailyForecast[] = [];
    const d7 = d7Resp.daily ?? [];
    for (let i = 0; i < Math.min(7, d7.length); i++) {
      const item = d7[i];
      daily.push({
        dateLabel: formatDayFromISO(item.fxDate) || `周${i + 1}`,
        highTemperature: Number(item.tempMax ?? 0),
        lowTemperature: Number(item.tempMin ?? 0),
        conditionText: item.textDay || codeToCondition(Number(item.iconDay ?? 0))
      });
    }

    // 当前接口组未直接取分钟降水，先由 24h pop 合成 60 分钟曲线
    const minuteRain: MinuteRainPoint[] = [];
    const seedHour = new Date().getHours();
    for (let m = 0; m < 60; m++) {
      const hourBucket = Math.floor(m / 5);
      const hourlyRef = hourly[Math.min(hourBucket, hourly.length - 1)];
      minuteRain.push({
        minuteLabel: `${pad2(seedHour)}:${pad2(m)}`.slice(0, 5),
        intensity: Math.max(0, Math.min(100, Math.round((hourlyRef?.precipitationProbability ?? 0) * 0.6)))
      });
    }

    const updateTime = now.obsTime || nowResp.updateTime || '';
    const lastUpdatedText = formatTimeFromISO(updateTime) || `${pad2(new Date().getHours())}:${pad2(new Date().getMinutes())}`;
    return {
      currentTemperature: currentTemp,
      currentConditionText,
      hourly,
      daily,
      lifeIndex: buildLifeIndexFromCurrent(currentConditionText),
      minuteRain,
      lastUpdatedText,
      cityName
    };
  }
}

type QWeatherResponseBase = {
  code: string;
  updateTime?: string;
};

type QNow = {
  obsTime: string;
  temp: string;
  text: string;
  icon: string;
};

type QNowResponse = QWeatherResponseBase & {
  now: QNow;
};

type QHourly = {
  fxTime: string;
  temp: string;
  text: string;
  icon: string;
  pop: string;
};

type Q24hResponse = QWeatherResponseBase & {
  hourly: QHourly[];
};

type QDaily = {
  fxDate: string;
  tempMax: string;
  tempMin: string;
  textDay: string;
  iconDay: string;
};

type Q7dResponse = QWeatherResponseBase & {
  daily: QDaily[];
};

