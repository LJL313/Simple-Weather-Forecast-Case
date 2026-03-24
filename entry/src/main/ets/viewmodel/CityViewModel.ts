import {
  getCityDisplayName,
  pickResolvableCityOrDefault,
  resolveCityLocationId
} from '../services/WeatherApiConfig';

export interface CityEntry {
  locationId: string;
  label: string;
}

/** 搜索历史：带 id 才能从胶囊直接切到准确站点 */
export interface SearchHistoryItem {
  locationId: string;
  name: string;
}

export interface CityState {
  cities: CityEntry[];
  currentLocationId: string;
  currentLabel: string;
}

export interface AddCityResult {
  state: CityState;
  errorMessage?: string;
}

export class CityViewModel {
  private readonly citiesV2Key: string = 'weatherCitiesV2Json';
  private readonly currentIdKey: string = 'weatherCurrentLocationId';
  /** 旧版：城市名列表 */
  private readonly legacyCitiesKey: string = 'weatherCitiesJson';
  /** 旧版：当前城市名 */
  private readonly legacyCurrentKey: string = 'weatherCurrentCityName';
  private readonly searchHistoryKey: string = 'weatherSearchHistoryJson';

  private readCitiesV2Raw(): CityEntry[] | null {
    try {
      const raw = AppStorage.get<string>(this.citiesV2Key) ?? '';
      if (!raw) {
        return null;
      }
      const arr = JSON.parse(raw) as object[];
      if (!Array.isArray(arr) || arr.length === 0) {
        return null;
      }
      const first = arr[0] as Record<string, string>;
      if (typeof first !== 'object' || first === null || first['locationId'] === undefined) {
        return null;
      }
      const out: CityEntry[] = [];
      for (let i = 0; i < arr.length; i++) {
        const row = arr[i] as Record<string, string>;
        const id = String(row['locationId'] ?? '').trim();
        const label = String(row['label'] ?? '').trim();
        if (id.length > 0 && label.length > 0) {
          out.push({ locationId: id, label });
        }
      }
      return out.length > 0 ? out : null;
    } catch {
      return null;
    }
  }

  private migrateLegacyCities(): CityEntry[] {
    let list: string[] = [];
    try {
      const raw = AppStorage.get<string>(this.legacyCitiesKey) ?? '';
      list = raw ? (JSON.parse(raw) as string[]) : [];
    } catch {
      list = [];
    }
    if (!Array.isArray(list) || list.length === 0) {
      list = ['深圳', '北京', '上海'];
    }
    const entries: CityEntry[] = [];
    for (let i = 0; i < list.length; i++) {
      const s = String(list[i]).trim();
      const id = resolveCityLocationId(s);
      if (id) {
        entries.push({ locationId: id, label: getCityDisplayName(s) });
      }
    }
    if (entries.length === 0) {
      entries.push({ locationId: '101280601', label: '深圳' });
    }
    return entries;
  }

  private resolveLegacyCurrentId(cities: CityEntry[]): string {
    let legacyName = '';
    try {
      legacyName = AppStorage.get<string>(this.legacyCurrentKey) ?? '';
    } catch {
      legacyName = '';
    }
    const trimmed = legacyName.trim();
    if (trimmed.length === 0) {
      return cities[0].locationId;
    }
    const byId = resolveCityLocationId(trimmed);
    if (byId) {
      const hit = cities.find((c) => c.locationId === byId);
      if (hit) {
        return hit.locationId;
      }
      return byId;
    }
    const fixedName = pickResolvableCityOrDefault(trimmed, JSON.stringify(cities.map((c) => c.label)));
    const id = resolveCityLocationId(fixedName);
    return id ?? cities[0].locationId;
  }

  load(): CityState {
    let cities = this.readCitiesV2Raw();
    if (!cities || cities.length === 0) {
      cities = this.migrateLegacyCities();
      AppStorage.setOrCreate(this.citiesV2Key, JSON.stringify(cities));
    }

    let currentId = '';
    try {
      currentId = AppStorage.get<string>(this.currentIdKey) ?? '';
    } catch {
      currentId = '';
    }
    currentId = currentId.trim();

    if (!currentId || !/^\d{6,15}$/.test(currentId)) {
      currentId = this.resolveLegacyCurrentId(cities);
      AppStorage.setOrCreate(this.currentIdKey, currentId);
    }

    let found = cities.find((c) => c.locationId === currentId);
    if (!found) {
      currentId = cities[0].locationId;
      AppStorage.setOrCreate(this.currentIdKey, currentId);
      found = cities[0];
    }

    return {
      cities,
      currentLocationId: currentId,
      currentLabel: found.label
    };
  }

  loadSearchHistory(): SearchHistoryItem[] {
    try {
      const raw = AppStorage.get<string>(this.searchHistoryKey) ?? '';
      if (!raw) {
        return [];
      }
      const parsed: unknown = JSON.parse(raw) as unknown;
      if (!Array.isArray(parsed) || parsed.length === 0) {
        return [];
      }
      const firstEl: unknown = parsed[0];
      if (typeof firstEl === 'string') {
        const out: SearchHistoryItem[] = [];
        for (let i = 0; i < parsed.length; i++) {
          const s = String(parsed[i]).trim();
          const id = resolveCityLocationId(s);
          if (id) {
            out.push({ locationId: id, name: getCityDisplayName(s) });
          }
        }
        return out.slice(0, 12);
      }
      const out2: SearchHistoryItem[] = [];
      for (let i = 0; i < parsed.length; i++) {
        const row = parsed[i] as Record<string, string>;
        const id = String(row['locationId'] ?? '').trim();
        const name = String(row['name'] ?? '').trim();
        if (id.length > 0 && name.length > 0) {
          out2.push({ locationId: id, name });
        }
      }
      return out2.slice(0, 12);
    } catch {
      return [];
    }
  }

  clearSearchHistory(): void {
    AppStorage.setOrCreate(this.searchHistoryKey, JSON.stringify([]));
  }

  private appendSearchHistory(item: SearchHistoryItem): void {
    const prev = this.loadSearchHistory();
    const next = [item, ...prev.filter((x) => x.locationId !== item.locationId)].slice(0, 12);
    AppStorage.setOrCreate(this.searchHistoryKey, JSON.stringify(next));
  }

  private persistCities(cities: CityEntry[], currentId: string): void {
    AppStorage.setOrCreate(this.citiesV2Key, JSON.stringify(cities));
    AppStorage.setOrCreate(this.currentIdKey, currentId);
  }

  /**
   * 从 Geo 结果添加：列表展示用短名 name，详情行可用完整 line
   */
  addCityFromGeo(locationId: string, listLabel: string, historyChipName: string): CityState {
    const id = locationId.trim();
    const label = listLabel.trim().length > 0 ? listLabel.trim() : historyChipName;
    const state = this.load();
    const exists = state.cities.find((c) => c.locationId === id);
    let nextCities: CityEntry[];
    if (exists) {
      nextCities = state.cities;
    } else {
      nextCities = [{ locationId: id, label }, ...state.cities];
    }
    this.persistCities(nextCities, id);
    this.appendSearchHistory({ locationId: id, name: historyChipName.trim().length > 0 ? historyChipName : label });
    return this.load();
  }

  /**
   * 内置表城市名 / 英文拼音（与原先一致）
   */
  addCity(cityName: string): AddCityResult {
    const name = cityName.trim();
    const state = this.load();
    if (!name) {
      return { state, errorMessage: '请输入城市名称' };
    }
    const id = resolveCityLocationId(name);
    if (!id) {
      return {
        state,
        errorMessage: '未找到匹配城市。请在下方的「全部城市」中选择具体地点，或尝试标准名称（如：长沙）。'
      };
    }
    const label = getCityDisplayName(name);
    const exists = state.cities.find((c) => c.locationId === id);
    let nextCities: CityEntry[];
    if (exists) {
      nextCities = state.cities;
    } else {
      nextCities = [{ locationId: id, label }, ...state.cities];
    }
    this.persistCities(nextCities, id);
    this.appendSearchHistory({ locationId: id, name: label });
    return { state: this.load() };
  }

  removeCity(locationId: string): CityState {
    const state = this.load();
    const nextList = state.cities.filter((c) => c.locationId !== locationId);

    if (nextList.length === 0) {
      const fallback: CityEntry = { locationId: '101280601', label: '深圳' };
      this.persistCities([fallback], fallback.locationId);
      return this.load();
    }

    const nextCurrent =
      state.currentLocationId === locationId ? nextList[0].locationId : state.currentLocationId;
    this.persistCities(nextList, nextCurrent);
    return this.load();
  }

  setCurrentCity(locationId: string): CityState {
    const state = this.load();
    const hit = state.cities.find((c) => c.locationId === locationId);
    if (!hit) {
      return state;
    }
    AppStorage.setOrCreate(this.currentIdKey, locationId);
    return this.load();
  }
}
