import { http } from '@kit.NetworkKit';
import { CITY_LOCATION_MAP, WEATHER_API_CONFIG, isWeatherAuthConfigured } from './WeatherApiConfig';

export interface GeoLookupHit {
  id: string;
  name: string;
  adm1: string;
  adm2: string;
  country: string;
}

function httpGet(url: string, headers: Record<string, string>): Promise<{ statusCode: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.createHttp();
    req.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 20000,
        readTimeout: 20000,
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

/** 列表展示用：长沙市，湖南省，中国 */
export function formatGeoHitLine(hit: GeoLookupHit): string {
  const country = hit.country || '中国';
  const adm1 = hit.adm1 || '';
  const adm2 = hit.adm2 || '';
  const name = hit.name || '';
  if (adm2.length > 0 && adm1.length > 0) {
    return `${name}，${adm2}，${adm1}，${country}`;
  }
  if (adm1.length > 0) {
    return `${name}，${adm1}，${country}`;
  }
  return `${name}，${country}`;
}

/**
 * 在线 Geo 失败或未开通时：从内置 CITY_LOCATION_MAP 的中文名做包含匹配（如「长沙」→ 长沙）
 */
export function localCityLookupFallback(keyword: string): GeoLookupHit[] {
  const q = keyword.trim();
  if (q.length === 0) {
    return [];
  }
  const seenId = new Set<string>();
  const out: GeoLookupHit[] = [];
  const keys = Object.keys(CITY_LOCATION_MAP);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    if (!/[\u4e00-\u9fff]/.test(k)) {
      continue;
    }
    if (!k.includes(q)) {
      continue;
    }
    const id = CITY_LOCATION_MAP[k];
    if (seenId.has(id)) {
      continue;
    }
    seenId.add(id);
    out.push({
      id,
      name: k,
      adm1: '',
      adm2: '',
      country: '中国'
    });
  }
  return out.slice(0, 20);
}

/**
 * 和风 GeoAPI 城市搜索
 * 正确路径为 /geo/v2/city/lookup（不是 /v2/city/lookup）
 * https://dev.qweather.com/docs/api/geoapi/city-lookup
 */
export async function lookupCities(keyword: string): Promise<GeoLookupHit[]> {
  const q = keyword.trim();
  if (q.length === 0) {
    return [];
  }
  // 未配置 Key 时仍可展示内置城市匹配；实况简讯会显示为「—」
  if (!isWeatherAuthConfigured()) {
    return localCityLookupFallback(q);
  }

  const base = `${WEATHER_API_CONFIG.geoHost}/geo/v2/city/lookup`;
  const key = WEATHER_API_CONFIG.apiKey.length > 0 ? WEATHER_API_CONFIG.apiKey : '';
  const url = `${base}?location=${encodeURIComponent(q)}&number=20&lang=zh&range=cn&key=${encodeURIComponent(key)}`;

  const headers: Record<string, string> = {};
  if (WEATHER_API_CONFIG.apiKey.length === 0 && WEATHER_API_CONFIG.bearerToken.length > 0) {
    headers['Authorization'] = `Bearer ${WEATHER_API_CONFIG.bearerToken}`;
  }

  let text: string;
  try {
    const resp = await httpGet(url, headers);
    if (resp.statusCode !== 200) {
      return localCityLookupFallback(q);
    }
    text = resp.body;
  } catch {
    return localCityLookupFallback(q);
  }

  interface GeoResp {
    code?: string;
    location?: Array<{
      id?: string;
      name?: string;
      adm1?: string;
      adm2?: string;
      country?: string;
    }>;
  }

  let parsed: GeoResp;
  try {
    parsed = JSON.parse(text) as GeoResp;
  } catch {
    return localCityLookupFallback(q);
  }
  if (parsed.code !== '200' || !parsed.location || !Array.isArray(parsed.location)) {
    return localCityLookupFallback(q);
  }

  const out: GeoLookupHit[] = [];
  for (let i = 0; i < parsed.location.length; i++) {
    const row = parsed.location[i];
    const id = row.id ?? '';
    if (!id) {
      continue;
    }
    out.push({
      id,
      name: row.name ?? '',
      adm1: row.adm1 ?? '',
      adm2: row.adm2 ?? '',
      country: row.country ?? '中国'
    });
  }
  if (out.length === 0) {
    return localCityLookupFallback(q);
  }
  return out;
}
