import { HourlyForecast, DailyForecast, LifeIndex } from '../model/WeatherState';
import type { WeatherProvider } from './WeatherProvider';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function formatTime(d: Date): string {
  return `${pad2(d.getHours())}:00`;
}

function formatDay(d: Date): string {
  const week = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return week[d.getDay()];
}

function mulberry32(seed: number): () => number {
  // Deterministic pseudo random for stable mock visuals.
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let x = Math.imul(t ^ (t >>> 15), 1 | t);
    x ^= x + Math.imul(x ^ (x >>> 7), 61 | x);
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

export class MockWeatherProvider implements WeatherProvider {
  async getWeather(_locationQuery: string, cityName: string): Promise<{
    currentTemperature: number;
    currentConditionText: string;
    hourly: HourlyForecast[];
    daily: DailyForecast[];
    lifeIndex: LifeIndex;
    minuteRain: { minuteLabel: string; intensity: number }[];
    lastUpdatedText: string;
    cityName: string;
  }> {
    const now = new Date();
    const seed = Array.from(cityName).reduce((sum, ch) => sum + ch.charCodeAt(0), 0) + now.getDate();
    const rnd = mulberry32(seed);

    // phase2：故意注入少量异常，让 UI 能展示 loading/error/offline 占位态（用于验证链路）
    const chaos = rnd();
    if (chaos > 0.955) {
      throw new Error('offline');
    }
    if (chaos < 0.03) {
      throw new Error('Network error');
    }

    const baseTemp = Math.round(18 + rnd() * 10); // 18~28
    const conditionPool = ['晴', '多云', '阴', '小雨'];
    const currentConditionText = conditionPool[Math.floor(rnd() * conditionPool.length)];

    const hourly: HourlyForecast[] = [];
    for (let i = 0; i < 24; i++) {
      const t = new Date(now.getTime() + i * 60 * 60 * 1000);
      const tempDelta = Math.sin((i / 24) * Math.PI * 2) * 4; // daily curve
      const temp = Math.round(baseTemp + tempDelta + (rnd() - 0.5) * 2);

      const isRainy = currentConditionText === '小雨' || rnd() > 0.75;
      const precipitationProbability = isRainy ? Math.round(30 + rnd() * 60) : Math.round(rnd() * 20);

      hourly.push({
        hourLabel: formatTime(t),
        temperature: temp,
        conditionText: currentConditionText,
        precipitationProbability
      });
    }

    // phase3：分钟级降水强度时间轴（接下来 60 分钟）
    const minuteRain: { minuteLabel: string; intensity: number }[] = [];
    for (let m = 0; m < 60; m++) {
      const t = new Date(now.getTime() + m * 60 * 1000);
      const hourBucket = Math.floor(m / 5); // coarse link to hourly curve
      const hourlyRef = hourly[Math.min(hourBucket, hourly.length - 1)];

      // 如果当前处于降雨/可能降雨，则提升强度；否则接近 0
      const rainFactor = currentConditionText === '小雨' ? 1 : 0.35;
      const jitter = (rnd() - 0.5) * 18;
      const intensity = Math.max(
        0,
        Math.round((hourlyRef?.precipitationProbability ?? 0) * 0.55 * rainFactor + jitter)
      );

      minuteRain.push({
        minuteLabel: `${pad2(t.getHours())}:${pad2(t.getMinutes())}`,
        intensity: Math.min(100, intensity)
      });
    }

    const daily: DailyForecast[] = [];
    for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
      const d = new Date(now.getTime() + dayOffset * 24 * 60 * 60 * 1000);
      const high = baseTemp + Math.round(3 + rnd() * 4);
      const low = baseTemp - Math.round(2 + rnd() * 4);
      const conditionText = rnd() > 0.7 ? '小雨' : (rnd() > 0.4 ? '多云' : '晴');
      daily.push({
        dateLabel: formatDay(d),
        highTemperature: high,
        lowTemperature: low,
        conditionText
      });
    }

    const lifeIndex: LifeIndex = {
      dressing: rnd() > 0.6 ? '适当加衣' : '穿衣适中',
      uvIndex: Math.round(1 + rnd() * 9),
      uvDesc: rnd() > 0.7 ? '注意防晒' : '可正常活动',
      airQualityText: rnd() > 0.6 ? '空气一般' : '空气良好'
    };

    return {
      currentTemperature: Math.round(baseTemp + (rnd() - 0.5) * 2),
      currentConditionText,
      hourly,
      daily,
      lifeIndex,
      minuteRain,
      lastUpdatedText: `${pad2(now.getHours())}:${pad2(now.getMinutes())}`,
      cityName
    };
  }
}

