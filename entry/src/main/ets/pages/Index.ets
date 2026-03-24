import { RealWeatherProvider } from '../services/RealWeatherProvider';
import { WeatherViewModel } from '../viewmodel/WeatherViewModel';
import { WeatherState } from '../model/WeatherState';
import type { HourlyForecast } from '../model/WeatherState';
import { getCityDisplayName } from '../services/WeatherApiConfig';
import { CityViewModel } from '../viewmodel/CityViewModel';
import { WeatherTopBar } from '../components/WeatherTopBar';
import { HourlyForecastCard } from '../components/HourlyForecastCard';
import { DailyForecastList } from '../components/DailyForecastList';
import { LifeIndexCard } from '../components/LifeIndexCard';
import { MinuteRainBarHeat } from '../components/MinuteRainBarHeat';
import { HourDetailOverlay } from '../components/HourDetailOverlay';
import { WeatherSpotlightCard } from '../components/WeatherSpotlightCard';
import { DesktopWidgetPreviewCard } from '../components/DesktopWidgetPreviewCard';
import { homeGradientStopsForCondition } from '../services/WeatherConditionVisual';
import mediaQuery from '@ohos.mediaquery';
import display from '@ohos.display';

interface ActiveCityContext {
  locationId: string;
  label: string;
}

@Entry
@Component
struct Index {
  // ArkUI doesn't expose a reactive "ViewModel container" by default; we keep it as a plain field
  // and push its async results into @State for re-render.
  // 优先走真实接口；真实接口失败时 provider 内部会回退到 mock（除 token/城市配置错误）
  private weatherVM: WeatherViewModel = new WeatherViewModel(new RealWeatherProvider(), '101280601', '深圳');
  private scroller: Scroller = new Scroller();

  // phase2：天气状态（loading/success/error/offline）由这里驱动 UI 占位态
  @State weatherState: WeatherState = WeatherState.empty();
  // phase2/phase5：下拉刷新状态
  @State isRefreshing: boolean = false;
  // phase5：深色模式适配开关
  @State isDarkMode: boolean = false;
  // phase5：横竖屏适配开关
  @State isLandscape: boolean = false;
  /** 下拉刷新结束后的顶部反馈（对齐华为「下午1:16 更新成功」） */
  @State refreshBanner: string = '';
  /** setTimeout 句柄，避免重复定时器 */
  private refreshBannerTimerId: number = -1;
  /** 刷新指示器最长展示时间（ms），超时也收起，避免请求挂起时一直转圈 */
  private static readonly REFRESH_UI_MAX_MS: number = 1000;

  /** 点击逐小时卡片：详情浮层 */
  @State hourDetailVisible: boolean = false;
  @State hourDetailSelected: HourlyForecast = {
    hourLabel: '',
    temperature: 0,
    conditionText: '',
    precipitationProbability: 0
  };
  private darkModeListener: mediaQuery.MediaQueryListener | undefined = undefined;

  private getActiveCityFromStorage(): ActiveCityContext {
    const cv = new CityViewModel();
    const s = cv.load();
    const ctx: ActiveCityContext = { locationId: s.currentLocationId, label: s.currentLabel };
    return ctx;
  }

  /**
   * 触发天气刷新。
   * @param silent 为 true 时不切到全屏「加载中」（用于下拉刷新）：避免子树从 Scroll 换成占位导致 Refresh 指示器卡死。
   */
  async refreshWeather(silent: boolean = false): Promise<void> {
    const ctx = this.getActiveCityFromStorage();
    this.weatherVM.setDefaultCity(ctx.locationId, ctx.label);
    this.hourDetailVisible = false;

    if (!silent) {
      const loading = WeatherState.empty();
      loading.status = 'loading';
      loading.cityName = ctx.label || this.weatherState.cityName;
      this.weatherState = loading;
    }

    this.weatherState = await this.weatherVM.refresh();
  }

  aboutToAppear(): void {
    // phase5：初始化深色模式监听 + 横竖屏判断
    try {
      const info = display.getDefaultDisplaySync();
      this.isLandscape = info.width > info.height;
    } catch {
      this.isLandscape = false;
    }
    try {
      this.darkModeListener = mediaQuery.matchMediaSync('(dark-mode: true)');
      this.isDarkMode = (this.darkModeListener?.matches as boolean) ?? false;
      this.darkModeListener?.on('change', (result: mediaQuery.MediaQueryResult) => {
        this.isDarkMode = (result.matches as boolean) ?? false;
      });
    } catch {
      // 深色监听不可用时，退回到浅色样式
      this.isDarkMode = false;
    }
  }

  /** 从城市管理页返回时 Index 不会再次 aboutToAppear，在此刷新以同步当前城市 */
  onPageShow(): void {
    void this.refreshWeather();
  }

  private openHourDetail(item: HourlyForecast): void {
    this.hourDetailSelected = {
      hourLabel: item.hourLabel,
      temperature: item.temperature,
      conditionText: item.conditionText,
      precipitationProbability: item.precipitationProbability
    };
    this.hourDetailVisible = true;
  }

  private closeHourDetail(): void {
    this.hourDetailVisible = false;
  }

  private delayMs(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  /** 异步回调里更新 @State，避免 Refresh 内部状态与 UI 不同步 */
  private endPullRefreshUi(): void {
    try {
      this.getUIContext().runScopedTask(() => {
        this.isRefreshing = false;
      });
    } catch {
      this.isRefreshing = false;
    }
  }

  private formatRefreshBanner(success: boolean): string {
    const d = new Date();
    const h24 = d.getHours();
    const m = d.getMinutes();
    const isPm = h24 >= 12;
    const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
    const mm = m < 10 ? `0${m}` : `${m}`;
    const ap = isPm ? '下午' : '上午';
    return success ? `${ap}${h12}:${mm} 更新成功` : `${ap}${h12}:${mm} 更新失败`;
  }

  private showRefreshBannerAfterPull(success: boolean): void {
    this.refreshBanner = this.formatRefreshBanner(success);
    if (this.refreshBannerTimerId !== -1) {
      clearTimeout(this.refreshBannerTimerId);
    }
    this.refreshBannerTimerId = setTimeout(() => {
      this.refreshBanner = '';
      this.refreshBannerTimerId = -1;
    }, 2600) as number;
  }

  /** 与内容区一致，铺在最底层，避免下拉刷新时露出默认白底 */
  private homePageGradientColors(): Array<[string, number]> {
    if (this.weatherState.status === 'success') {
      return homeGradientStopsForCondition(this.weatherState.currentConditionText);
    }
    return [
      ['#8FA0B2', 0.0],
      ['#6B7C8E', 0.45],
      ['#4E5D6C', 1.0]
    ];
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 165,
          colors: this.homePageGradientColors()
        });

      // 子节点必须是可滚动组件（如 Scroll），否则 refreshing 置 false 后指示器仍可能卡住；refreshing 用单向绑定避免与 $$ 内状态冲突
      Refresh({ refreshing: this.isRefreshing }) {
        Scroll() {
          Column({ space: this.isLandscape ? 10 : 12 }) {
        if (this.refreshBanner.length > 0) {
          Text(this.refreshBanner)
            .fontSize(13)
            .fontColor('#F5F7FA')
            .opacity(0.95)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 2, bottom: 4 });
        }
        // phase2：状态驱动 UI 占位态
        if (this.weatherState.status === 'loading') {
          Column() {
            Text('加载天气中...')
              .fontSize(16)
              .fontColor('#F5F7FA')
              .opacity(0.92)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center);
        } else if (this.weatherState.status === 'offline') {
          Column() {
            Text('网络不可用，请检查网络连接。')
              .fontSize(16)
              .fontColor('#F5F7FA')
              .opacity(0.9);
            Button('重试')
              .fontColor('#1A2B3C')
              .backgroundColor('#E8EEF5')
              .margin({ top: 12 })
              .onClick(() => {
                this.refreshWeather();
              });
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center);
        } else if (this.weatherState.status === 'error') {
          Column() {
            if (this.weatherState.errorMessage === 'location_failed') {
              Text('定位失败：当前城市名称无法解析为经纬度。')
                .fontSize(16)
                .fontColor('#F5F7FA')
                .opacity(0.9);
              Text('请先选择内置城市，或稍后重试。')
                .fontSize(12)
                .fontColor('#F5F7FA')
                .opacity(0.72)
                .margin({ top: 8 });
            } else if (this.weatherState.errorMessage === 'token_missing') {
              Text('未配置和风天气密钥。')
                .fontSize(16)
                .fontColor('#F5F7FA')
                .opacity(0.9);
              Text('请在 services/WeatherApiConfig.ts 中填写 apiKey（控制台复制的 API Key）。')
                .fontSize(12)
                .fontColor('#F5F7FA')
                .opacity(0.72)
                .margin({ top: 8 });
            } else {
              Text('天气加载失败。')
                .fontSize(16)
                .fontColor('#F5F7FA')
                .opacity(0.9);
            }
            if (this.weatherState.errorMessage) {
              if (this.weatherState.errorMessage !== 'location_failed') {
                Text(this.weatherState.errorMessage)
                  .fontSize(12)
                  .fontColor('#F5F7FA')
                  .opacity(0.65)
                  .margin({ top: 8 });
              }
            }
            Button('重试')
              .fontColor('#1A2B3C')
              .backgroundColor('#E8EEF5')
              .margin({ top: 12 })
              .onClick(() => {
                this.refreshWeather();
              });
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center);
        } else {
          // success：纵向滚动由外层 Refresh 下的 Scroll 负责
          Column({ space: this.isLandscape ? 10 : 12 }) {
              WeatherTopBar({
                cityName: getCityDisplayName(this.weatherState.cityName),
                temperature: this.weatherState.currentTemperature,
                conditionText: this.weatherState.currentConditionText,
                lastUpdatedText: this.weatherState.lastUpdatedText,
                status: this.weatherState.status,
                huaweiStyle: true
              });

              WeatherSpotlightCard({ huaweiStyle: true });

              // 横向逐小时：Row 不要设 width('100%')，否则行宽被压成屏宽，无法横向溢出滚动
              Scroll(this.scroller) {
                Row({ space: 10 }) {
                  ForEach(
                    this.weatherState.hourly,
                    (item: HourlyForecast, index: number) => {
                      Column() {
                        HourlyForecastCard({ item: item, huaweiStyle: true });
                      }
                      .onClick(() => {
                        this.openHourDetail(item);
                      });
                    },
                    (item: HourlyForecast, index: number) => `${item.hourLabel}_${index}`
                  )
                }
                .padding({ left: 2, right: 16 })
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
              .nestedScroll({
                scrollForward: NestedScrollMode.SELF_FIRST,
                scrollBackward: NestedScrollMode.SELF_FIRST
              })

              MinuteRainBarHeat({ points: this.weatherState.minuteRain, huaweiStyle: true })

              Column({ space: 12 }) {
                DailyForecastList({ daily: this.weatherState.daily, huaweiStyle: true })
                LifeIndexCard({ lifeIndex: this.weatherState.lifeIndex, huaweiStyle: true })
                DesktopWidgetPreviewCard({
                  cityName: getCityDisplayName(this.weatherState.cityName),
                  currentTemperature: this.weatherState.currentTemperature,
                  conditionText: this.weatherState.currentConditionText,
                  highLowText: this.weatherState.daily.length > 0
                    ? `${Math.round(this.weatherState.daily[0].highTemperature)}~${Math.round(this.weatherState.daily[0].lowTemperature)}°C`
                    : '--/--°C',
                  updatedText: this.weatherState.lastUpdatedText,
                  hourly: this.weatherState.hourly
                })
              }
              .padding({ left: 0, right: 0, bottom: 32 })
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);
        }
          }
          .width('100%')
          .padding(this.isLandscape ? 12 : 16)
          .constraintSize({ minHeight: '100%' })
          .backgroundColor(Color.Transparent);
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .backgroundColor(Color.Transparent);
      }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .pullToRefresh(true)
    .refreshOffset(64)
    .onRefreshing(() => {
      if (this.isRefreshing) {
        return;
      }
      this.isRefreshing = true;
      const task = this.refreshWeather(true);
      void Promise.race([task, this.delayMs(Index.REFRESH_UI_MAX_MS)]).finally(() => {
        this.endPullRefreshUi();
      });
      void task.then(() => {
        if (this.weatherState.status === 'success') {
          this.showRefreshBannerAfterPull(true);
        } else {
          this.showRefreshBannerAfterPull(false);
        }
      });
    });

    if (this.hourDetailVisible) {
      HourDetailOverlay({
        item: this.hourDetailSelected,
        cityDisplayName: getCityDisplayName(this.weatherState.cityName),
        onClose: () => {
          this.closeHourDetail();
        }
      });
    }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#6D7E90')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

