import type { WeatherProvider } from '../services/WeatherProvider';
import { applyProviderDataToState } from '../services/WeatherProvider';
import { WeatherState } from '../model/WeatherState';

export class WeatherViewModel {
  private provider: WeatherProvider;
  private defaultLocationId: string;
  private defaultDisplayName: string;
  private inFlight: Promise<WeatherState> | undefined;
  private lastRefreshTs: number = 0;
  private debounceMs: number = 500;

  constructor(
    provider: WeatherProvider,
    defaultLocationId: string = '101280601',
    defaultDisplayName: string = '深圳'
  ) {
    this.provider = provider;
    this.defaultLocationId = defaultLocationId;
    this.defaultDisplayName = defaultDisplayName;
  }

  async refresh(): Promise<WeatherState> {
    const locId = this.defaultLocationId;
    const label = this.defaultDisplayName;

    const now = Date.now();

    if (this.inFlight) return this.inFlight;
    if (now - this.lastRefreshTs < this.debounceMs && this.lastRefreshTs !== 0) {
      // 软节流
    }
    this.lastRefreshTs = now;

    this.inFlight = (async () => {
      try {
        const data = await this.provider.getWeather(locId, label);
        const next = WeatherState.empty();
        applyProviderDataToState(next, data);
        next.status = 'success';
        return next;
      } catch (e) {
        const next = WeatherState.empty();
        next.cityName = label;
        const msg = e instanceof Error ? e.message : String(e);
        if (msg === 'offline') {
          next.status = 'offline';
        } else {
          next.status = 'error';
        }
        next.errorMessage = msg || 'Unknown error';
        return next;
      }
    })();

    try {
      return await this.inFlight;
    } finally {
      this.inFlight = undefined;
    }
  }

  setDefaultCity(locationId: string, displayName: string) {
    this.defaultLocationId = locationId;
    this.defaultDisplayName = displayName;
  }
}
