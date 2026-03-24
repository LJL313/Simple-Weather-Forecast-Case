// 和风天气 API 配置（https://dev.qweather.com）
//
// 【推荐·简单】控制台「项目管理」里创建应用后，复制「API Key」填到 apiKey。
// 请求会使用：...?location=xxx&key=你的Key（与官方文档一致）
//
// 【日志里 NETSTACK RespCode:403】表示服务器拒绝访问，常见原因：
// Key 错误/过期、应用未勾选「天气预报」等数据权限、试用额度用尽、或 host 与 Key 环境不一致。
// 此时城市管理列表会显示「离线预览」占位数据；修好 Key 后即恢复真实天气。
//
// 【进阶】若你按文档做了 JWT/Ed25519 认证，则把每次请求前生成的 JWT 字符串填到 bearerToken
// （图片里 OpenSSL 生成密钥是 JWT 方案，不是“复制一个固定字符串”那种）
//
// host：免费开发环境一般为 devapi；若控制台给了专属域名再改
export const WEATHER_API_CONFIG = {
  host: 'https://devapi.qweather.com',
  /** Geo 城市搜索域名（与天气 devapi 可不同；若此处请求失败会自动走本地城市表兜底） */
  geoHost: 'https://geoapi.qweather.com',
  /** 控制台复制的 API Key（二选一，优先使用） */
  apiKey: '668eb8d9c890450f98a1732c0d5933c7',
  /** JWT 方式时的 Bearer Token（二选一；与 apiKey 同时填时优先 apiKey） */
  bearerToken: '',
  lang: 'zh',
  unit: 'm'
};

/** 是否已配置任一认证方式 */
export function isWeatherAuthConfigured(): boolean {
  return (
    (WEATHER_API_CONFIG.apiKey !== undefined && WEATHER_API_CONFIG.apiKey.length > 0) ||
    (WEATHER_API_CONFIG.bearerToken !== undefined && WEATHER_API_CONFIG.bearerToken.length > 0)
  );
}

// 常用城市 location ID（和风城市 ID，见控制台 / GeoAPI）
// 文档说明 location 可用城市ID或经纬度
export const CITY_LOCATION_MAP: Record<string, string> = {
  Shenzhen: '101280601',
  Beijing: '101010100',
  Shanghai: '101020100',
  Guangzhou: '101280101',
  Changsha: '101250101',
  Hangzhou: '101210101',
  Chengdu: '101270101',
  Nanjing: '101190101',
  Wuhan: '101200101',
  Xian: '101110101',
  Chongqing: '101040100',
  Tianjin: '101030100',
  Suzhou: '101190401',
  Zhengzhou: '101180101',
  Qingdao: '101120201',
  Xiamen: '101230201',
  Fuzhou: '101230101',
  Harbin: '101050101',
  Shenyang: '101070101',
  Changchun: '101060101',
  Kunming: '101290101',
  Hefei: '101220101',
  Nanchang: '101240101',
  Nanning: '101300101',
  Haikou: '101310101',
  Guiyang: '101260101',
  Taiyuan: '101100101',
  Shijiazhuang: '101090101',
  Jinan: '101120101',
  广州: '101280101',
  深圳: '101280601',
  北京: '101010100',
  上海: '101020100',
  长沙: '101250101',
  杭州: '101210101',
  成都: '101270101',
  南京: '101190101',
  武汉: '101200101',
  西安: '101110101',
  重庆: '101040100',
  天津: '101030100',
  苏州: '101190401',
  郑州: '101180101',
  青岛: '101120201',
  厦门: '101230201',
  福州: '101230101',
  哈尔滨: '101050101',
  沈阳: '101070101',
  长春: '101060101',
  昆明: '101290101',
  合肥: '101220101',
  南昌: '101240101',
  南宁: '101300101',
  海口: '101310101',
  贵阳: '101260101',
  太原: '101100101',
  石家庄: '101090101',
  济南: '101120101'
};

const DEFAULT_WEATHER_CITY = '深圳';
const DEFAULT_LOCATION_ID = '101280601';

/** 去掉首尾空格后查和风城市 ID；支持英文 key 大小写不敏感；纯数字视为已是 locationId */
export function resolveCityLocationId(cityName: string): string | undefined {
  const key = cityName.trim();
  if (!key) {
    return undefined;
  }
  if (/^\d{6,15}$/.test(key)) {
    return key;
  }
  const direct = CITY_LOCATION_MAP[key];
  if (direct) {
    return direct;
  }
  const lower = key.toLowerCase();
  const keys = Object.keys(CITY_LOCATION_MAP);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    if (k.toLowerCase() === lower) {
      return CITY_LOCATION_MAP[k];
    }
  }
  return undefined;
}

/**
 * 持久化里可能是旧数据、手输城市或带空格：纠正为能请求到天气的城市名并写回 AppStorage
 */
export function pickResolvableCityOrDefault(persistedCurrent: string, citiesJson: string): string {
  const cur = persistedCurrent.trim();
  if (resolveCityLocationId(cur)) {
    return cur;
  }
  let list: string[] = [];
  try {
    const parsed = citiesJson ? JSON.parse(citiesJson) as string[] : [];
    list = Array.isArray(parsed) ? parsed : [];
  } catch {
    list = [];
  }
  for (let i = 0; i < list.length; i++) {
    const c = String(list[i]).trim();
    if (resolveCityLocationId(c)) {
      return c;
    }
  }
  return DEFAULT_WEATHER_CITY;
}

export function getDefaultWeatherCity(): string {
  return DEFAULT_WEATHER_CITY;
}

export function getDefaultLocationId(): string {
  return DEFAULT_LOCATION_ID;
}

/** 界面展示用中文地名（内部查询仍用 AppStorage 里的 key） */
export const CITY_DISPLAY_MAP: Record<string, string> = {
  Shenzhen: '深圳',
  Beijing: '北京',
  Shanghai: '上海',
  Guangzhou: '广州',
  Changsha: '长沙',
  Hangzhou: '杭州',
  Chengdu: '成都',
  Nanjing: '南京',
  Wuhan: '武汉',
  Xian: '西安',
  Chongqing: '重庆',
  Tianjin: '天津',
  Suzhou: '苏州',
  Zhengzhou: '郑州',
  Qingdao: '青岛',
  Xiamen: '厦门',
  Fuzhou: '福州',
  Harbin: '哈尔滨',
  Shenyang: '沈阳',
  Changchun: '长春',
  Kunming: '昆明',
  Hefei: '合肥',
  Nanchang: '南昌',
  Nanning: '南宁',
  Haikou: '海口',
  Guiyang: '贵阳',
  Taiyuan: '太原',
  Shijiazhuang: '石家庄',
  Jinan: '济南',
  深圳: '深圳',
  北京: '北京',
  上海: '上海',
  广州: '广州',
  长沙: '长沙',
  杭州: '杭州',
  成都: '成都',
  南京: '南京',
  武汉: '武汉',
  西安: '西安',
  重庆: '重庆',
  天津: '天津',
  苏州: '苏州',
  郑州: '郑州',
  青岛: '青岛',
  厦门: '厦门',
  福州: '福州',
  哈尔滨: '哈尔滨',
  沈阳: '沈阳',
  长春: '长春',
  昆明: '昆明',
  合肥: '合肥',
  南昌: '南昌',
  南宁: '南宁',
  海口: '海口',
  贵阳: '贵阳',
  太原: '太原',
  石家庄: '石家庄',
  济南: '济南'
};

export function getCityDisplayName(internalName: string): string {
  return CITY_DISPLAY_MAP[internalName] ?? internalName;
}

/** 城市管理页「热门城市」展示顺序（均为已配置和风 location 的城市） */
export const HOT_CITY_DISPLAY_ORDER: string[] = [
  '北京',
  '上海',
  '深圳',
  '广州',
  '杭州',
  '成都',
  '重庆',
  '武汉',
  '西安',
  '南京',
  '长沙',
  '苏州'
];

