import { http } from '@kit.NetworkKit';
import { WEATHER_API_CONFIG, isWeatherAuthConfigured } from './WeatherApiConfig';

export interface NowWeatherSnippet {
  temp: number;
  text: string;
}

function httpGet(url: string, headers: Record<string, string>): Promise<{ statusCode: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.createHttp();
    req.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 15000,
        readTimeout: 15000,
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
        let body = '';
        if (typeof raw === 'string') {
          body = raw;
        } else if (raw !== undefined && raw !== null) {
          try {
            body = JSON.stringify(raw);
          } catch {
            body = '';
          }
        }
        req.destroy();
        resolve({ statusCode, body });
      }
    );
  });
}

async function getNowWeatherWithStatus(locationId: string): Promise<{ httpStatus: number; snippet?: NowWeatherSnippet }> {
  const id = locationId.trim();
  if (!id || !isWeatherAuthConfigured()) {
    return { httpStatus: 0 };
  }

  const base = `${WEATHER_API_CONFIG.host}/v7/weather/now?location=${encodeURIComponent(id)}&lang=${WEATHER_API_CONFIG.lang}&unit=${WEATHER_API_CONFIG.unit}`;
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
      return { httpStatus: resp.statusCode };
    }
    text = resp.body;
  } catch {
    return { httpStatus: 0 };
  }

  interface NowBody {
    code?: string | number;
    now?: { temp?: string; text?: string };
  }

  let parsed: NowBody;
  try {
    parsed = JSON.parse(text) as NowBody;
  } catch {
    return { httpStatus: 200 };
  }
  if (!qWeatherCodeOk(parsed.code) || !parsed.now) {
    return { httpStatus: 200 };
  }
  const t = Number(parsed.now.temp ?? NaN);
  if (isNaN(t)) {
    return { httpStatus: 200 };
  }
  return {
    httpStatus: 200,
    snippet: {
      temp: t,
      text: parsed.now.text ?? ''
    }
  };
}

/** 仅请求实时天气，用于城市管理搜索列表右侧简讯（控制并发由调用方限制） */
export async function fetchNowWeatherSnippet(locationId: string): Promise<NowWeatherSnippet | undefined> {
  const r = await getNowWeatherWithStatus(locationId);
  return r.snippet;
}

/** 列表行展示：图标 + 现象 + 最高/最低（对齐华为天气热门城市样式） */
export interface ListRowWeatherSummary {
  emoji: string;
  conditionText: string;
  rangeText: string;
}

/** 和风返回 code 多为字符串 "200"，少数场景可能为数字 */
function qWeatherCodeOk(code: string | number | undefined): boolean {
  if (code === undefined || code === null) {
    return false;
  }
  if (typeof code === 'number') {
    return code === 200;
  }
  const s = String(code).trim();
  return s === '200';
}

function buildWeatherGetUrl(pathWithQuery: string): { url: string; headers: Record<string, string> } {
  const base = `${WEATHER_API_CONFIG.host}${pathWithQuery}`;
  const sep = pathWithQuery.includes('?') ? '&' : '?';
  const url =
    WEATHER_API_CONFIG.apiKey.length > 0
      ? `${base}${sep}key=${encodeURIComponent(WEATHER_API_CONFIG.apiKey)}`
      : base;
  const headers: Record<string, string> = {};
  if (WEATHER_API_CONFIG.apiKey.length === 0 && WEATHER_API_CONFIG.bearerToken.length > 0) {
    headers['Authorization'] = `Bearer ${WEATHER_API_CONFIG.bearerToken}`;
  }
  return { url, headers };
}

/** 和风天气图标代码 → 单行 emoji（近似） */
function weatherIconCodeToEmoji(icon: string): string {
  const n = parseInt(icon, 10);
  if (isNaN(n)) {
    return '🌤️';
  }
  if (n === 100 || n === 150) {
    return '☀️';
  }
  if (n >= 101 && n <= 103) {
    return '⛅';
  }
  if (n === 104 || n === 151 || n === 152) {
    return '☁️';
  }
  if (n >= 300 && n <= 399) {
    return '🌧️';
  }
  if (n >= 400 && n <= 499) {
    return '❄️';
  }
  if (n >= 500 && n <= 515) {
    return '🌫️';
  }
  return '🌤️';
}

function emojiFromConditionText(t: string): string {
  if (t.includes('雷')) {
    return '⛈️';
  }
  if (t.includes('雨')) {
    return '🌧️';
  }
  if (t.includes('雪')) {
    return '❄️';
  }
  if (t.includes('雾') || t.includes('霾')) {
    return '🌫️';
  }
  if (t.includes('云') || t.includes('阴')) {
    return '☁️';
  }
  if (t.includes('晴')) {
    return '☀️';
  }
  return '🌤️';
}

function mulberry32List(seed: number): () => number {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let x = Math.imul(t ^ (t >>> 15), 1 | t);
    x ^= x + Math.imul(x ^ (x >>> 7), 61 | x);
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

function hashLocationLabel(locationId: string, displayLabel: string): number {
  const s = `${locationId}\0${displayLabel}`;
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/**
 * 接口 403/断网时列表行仍展示布局（与 Mock 同源算法，按城市稳定随机）
 * 文案含「离线预览」便于与真实数据区分
 */
export function buildListRowOfflinePreview(locationId: string, displayLabel: string): ListRowWeatherSummary {
  const d = new Date();
  const seed = hashLocationLabel(locationId, displayLabel) + d.getDate();
  const rnd = mulberry32List(seed);
  const baseTemp = Math.round(18 + rnd() * 10);
  const conditionPool = ['晴', '多云', '阴', '小雨'];
  const cond = conditionPool[Math.floor(rnd() * conditionPool.length)];
  const high = baseTemp + Math.round(2 + rnd() * 4);
  const low = baseTemp - Math.round(2 + rnd() * 4);
  return {
    emoji: emojiFromConditionText(cond),
    conditionText: `${cond} · 离线预览`,
    rangeText: `${high} / ${low}°C`
  };
}

function isAuthRejectedHttpStatus(status: number): boolean {
  return status === 401 || status === 402 || status === 403;
}

interface DailyFirstBody {
  code?: string | number;
  daily?: Array<{
    tempMax?: string;
    tempMin?: string;
    textDay?: string;
    iconDay?: string;
  }>;
}

function parseDailyFirstSummary(text: string): ListRowWeatherSummary | undefined {
  let parsed: DailyFirstBody;
  try {
    parsed = JSON.parse(text) as DailyFirstBody;
  } catch {
    return undefined;
  }
  if (!qWeatherCodeOk(parsed.code) || !parsed.daily || parsed.daily.length === 0) {
    return undefined;
  }
  const d0 = parsed.daily[0];
  const tMax = Number(d0.tempMax ?? NaN);
  const tMin = Number(d0.tempMin ?? NaN);
  const cond = d0.textDay ?? '';
  const icon = d0.iconDay ?? '';
  if (isNaN(tMax) || isNaN(tMin)) {
    return undefined;
  }
  return {
    emoji: weatherIconCodeToEmoji(icon),
    conditionText: cond.length > 0 ? cond : '—',
    rangeText: `${Math.round(tMax)} / ${Math.round(tMin)}°C`
  };
}

async function getDailyFirstWithStatus(
  apiPath: string,
  locationId: string
): Promise<{ httpStatus: number; summary?: ListRowWeatherSummary }> {
  const id = locationId.trim();
  if (!id || !isWeatherAuthConfigured()) {
    return { httpStatus: 0 };
  }
  const q = `location=${encodeURIComponent(id)}&lang=${WEATHER_API_CONFIG.lang}&unit=${WEATHER_API_CONFIG.unit}`;
  const { url, headers } = buildWeatherGetUrl(`${apiPath}?${q}`);
  try {
    const resp = await httpGet(url, headers);
    if (resp.statusCode !== 200) {
      return { httpStatus: resp.statusCode };
    }
    if (resp.body.length === 0) {
      return { httpStatus: 200 };
    }
    const summary = parseDailyFirstSummary(resp.body);
    return { httpStatus: 200, summary };
  } catch {
    return { httpStatus: 0 };
  }
}

/**
 * 7d → 3d → now；遇 HTTP 401/402/403 不再连环请求（与日志中大量 403 一致），直接离线预览
 */
export async function fetchWeatherListRowSummary(
  locationId: string,
  displayLabel: string = ''
): Promise<ListRowWeatherSummary> {
  const id = locationId.trim();
  if (!id || !isWeatherAuthConfigured()) {
    return buildListRowOfflinePreview(id, displayLabel);
  }

  const d7 = await getDailyFirstWithStatus('/v7/weather/7d', id);
  if (isAuthRejectedHttpStatus(d7.httpStatus)) {
    return buildListRowOfflinePreview(id, displayLabel);
  }
  if (d7.summary) {
    return d7.summary;
  }

  const d3 = await getDailyFirstWithStatus('/v7/weather/3d', id);
  if (isAuthRejectedHttpStatus(d3.httpStatus)) {
    return buildListRowOfflinePreview(id, displayLabel);
  }
  if (d3.summary) {
    return d3.summary;
  }

  const nw = await getNowWeatherWithStatus(id);
  if (isAuthRejectedHttpStatus(nw.httpStatus)) {
    return buildListRowOfflinePreview(id, displayLabel);
  }
  if (nw.snippet) {
    return {
      emoji: emojiFromConditionText(nw.snippet.text),
      conditionText: nw.snippet.text.length > 0 ? nw.snippet.text : '—',
      rangeText: `${Math.round(nw.snippet.temp)}°C`
    };
  }

  return buildListRowOfflinePreview(id, displayLabel);
}
