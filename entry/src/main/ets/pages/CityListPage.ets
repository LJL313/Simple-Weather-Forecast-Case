import router from '@ohos.router';
import { CityViewModel, type CityEntry, type CityState, type SearchHistoryItem } from '../viewmodel/CityViewModel';
import { HOT_CITY_DISPLAY_ORDER, resolveCityLocationId } from '../services/WeatherApiConfig';
import { lookupCities, type GeoLookupHit } from '../services/GeoCityLookup';
import { fetchWeatherListRowSummary } from '../services/WeatherNowSnippet';

/** 搜索行：天气字段随异步更新，整行 @State 替换以触发 ForEach 重绘（避免只改并行 string[] 不刷新） */
interface GeoSearchRowView {
  hit: GeoLookupHit;
  emoji: string;
  conditionText: string;
  rangeText: string;
}

interface HotCityRowView {
  rank: number;
  label: string;
  locationId: string;
  emoji: string;
  conditionText: string;
  rangeText: string;
}

interface MyCityRowView {
  entry: CityEntry;
  emoji: string;
  conditionText: string;
  rangeText: string;
}

@Entry
@Component
struct CityListPage {
  private cityVM: CityViewModel = new CityViewModel();
  private debounceTimer: number = 0;
  /** 防止异步搜索/实况与新一轮输入交错 */
  private lookupGeneration: number = 0;

  @State cities: CityEntry[] = [];
  @State currentLocationId: string = '';
  @State newCityName: string = '';
  @State searchHistory: SearchHistoryItem[] = [];
  @State hintText: string = '';
  @State geoSearchRows: GeoSearchRowView[] = [];
  @State geoLoading: boolean = false;
  @State hotCityRows: HotCityRowView[] = [];
  @State myCityRows: MyCityRowView[] = [];

  aboutToAppear(): void {
    this.syncFromStorage();
    this.rebuildMyCityRows();
    this.refreshHotCityRowsWeather();
  }

  /** 从首页返回时同步持久化并刷新列表简讯 */
  onPageShow(): void {
    this.syncFromStorage();
    this.rebuildMyCityRows();
    this.refreshHotCityRowsWeather();
  }

  private syncFromStorage(): void {
    const s = this.cityVM.load();
    this.cities = s.cities;
    this.currentLocationId = s.currentLocationId;
    this.searchHistory = this.cityVM.loadSearchHistory();
  }

  private applyCityState(s: CityState): void {
    this.cities = s.cities;
    this.currentLocationId = s.currentLocationId;
    this.searchHistory = this.cityVM.loadSearchHistory();
    this.rebuildMyCityRows();
  }

  private rebuildMyCityRows(): void {
    this.myCityRows = this.cities.map((e: CityEntry): MyCityRowView => {
      const row: MyCityRowView = {
        entry: e,
        emoji: '',
        conditionText: '',
        rangeText: '…'
      };
      return row;
    });
    void this.loadMyCityRowSummaries();
  }

  /** 按 locationId 回写行，避免 aboutToAppear/onPageShow 连触发时 gen 校验把有效结果全部丢弃 */
  private async loadMyCityRowSummaries(): Promise<void> {
    const cap = Math.min(12, this.myCityRows.length);
    for (let i = 0; i < cap; i++) {
      const id = this.myCityRows[i].entry.locationId;
      const label = this.myCityRows[i].entry.label;
      const sum = await fetchWeatherListRowSummary(id, label);
      const idx = this.myCityRows.findIndex((r: MyCityRowView) => r.entry.locationId === id);
      if (idx < 0) {
        continue;
      }
      if (this.myCityRows[idx].entry.locationId !== id) {
        continue;
      }
      const next = [...this.myCityRows];
      const updated: MyCityRowView = {
        entry: next[idx].entry,
        emoji: sum.emoji,
        conditionText: sum.conditionText,
        rangeText: sum.rangeText
      };
      next[idx] = updated;
      this.myCityRows = next;
    }
  }

  private refreshHotCityRowsWeather(): void {
    const rows: HotCityRowView[] = [];
    for (let i = 0; i < HOT_CITY_DISPLAY_ORDER.length; i++) {
      const label = HOT_CITY_DISPLAY_ORDER[i];
      const locationId = resolveCityLocationId(label);
      if (!locationId || locationId.length === 0) {
        continue;
      }
      const hotRow: HotCityRowView = {
        rank: i + 1,
        label,
        locationId,
        emoji: '',
        conditionText: '',
        rangeText: '…'
      };
      rows.push(hotRow);
    }
    this.hotCityRows = rows;
    void this.loadHotCityRowSummaries();
  }

  private async loadHotCityRowSummaries(): Promise<void> {
    const cap = Math.min(12, this.hotCityRows.length);
    for (let i = 0; i < cap; i++) {
      const id = this.hotCityRows[i].locationId;
      const label = this.hotCityRows[i].label;
      const sum = await fetchWeatherListRowSummary(id, label);
      const idx = this.hotCityRows.findIndex((r: HotCityRowView) => r.locationId === id);
      if (idx < 0) {
        continue;
      }
      if (this.hotCityRows[idx].locationId !== id) {
        continue;
      }
      const next = [...this.hotCityRows];
      const updatedHot: HotCityRowView = {
        rank: next[idx].rank,
        label: next[idx].label,
        locationId: next[idx].locationId,
        emoji: sum.emoji,
        conditionText: sum.conditionText,
        rangeText: sum.rangeText
      };
      next[idx] = updatedHot;
      this.hotCityRows = next;
    }
  }

  private rankAccentColor(index: number): string {
    if (index === 0) {
      return '#FF8F3F';
    }
    if (index === 1) {
      return '#FFB34D';
    }
    if (index === 2) {
      return '#FFCC66';
    }
    return 'rgba(255,255,255,0.5)';
  }

  private scheduleGeoSearch(raw: string): void {
    if (this.debounceTimer !== 0) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = 0;
    }
    const q = raw.trim();
    if (q.length === 0) {
      this.geoSearchRows = [];
      this.geoLoading = false;
      return;
    }
    this.geoLoading = true;
    this.debounceTimer = setTimeout(() => {
      this.debounceTimer = 0;
      void this.runLiveLookup(q);
    }, 380);
  }

  private async runLiveLookup(q: string): Promise<void> {
    const gen = ++this.lookupGeneration;
    const list = await lookupCities(q);
    if (gen !== this.lookupGeneration) {
      return;
    }
    this.geoSearchRows = list.map((h: GeoLookupHit): GeoSearchRowView => {
      const row: GeoSearchRowView = {
        hit: h,
        emoji: '',
        conditionText: '',
        rangeText: '…'
      };
      return row;
    });
    this.geoLoading = false;
    const locationIds: string[] = [];
    for (let j = 0; j < list.length; j++) {
      locationIds.push(list[j].id);
    }
    void this.loadGeoSearchRowSummaries(locationIds);
  }

  /** 前 8 条拉简讯；用 id 列表回写，避免 gen 与异步交错导致永远不更新 */
  private async loadGeoSearchRowSummaries(locationIds: string[]): Promise<void> {
    const cap = Math.min(8, locationIds.length);
    for (let i = 0; i < cap; i++) {
      const hid = locationIds[i];
      const hitRow = this.geoSearchRows.find((r: GeoSearchRowView) => r.hit.id === hid);
      const geoLabel = hitRow ? hitRow.hit.name : '';
      const sum = await fetchWeatherListRowSummary(hid, geoLabel);
      const idx = this.geoSearchRows.findIndex((r: GeoSearchRowView) => r.hit.id === hid);
      if (idx < 0) {
        continue;
      }
      if (this.geoSearchRows[idx].hit.id !== hid) {
        continue;
      }
      const next = [...this.geoSearchRows];
      const updatedGeo: GeoSearchRowView = {
        hit: next[idx].hit,
        emoji: sum.emoji,
        conditionText: sum.conditionText,
        rangeText: sum.rangeText
      };
      next[idx] = updatedGeo;
      this.geoSearchRows = next;
    }
  }

  private onAddClick(): void {
    const r = this.cityVM.addCity(this.newCityName);
    if (!r.errorMessage) {
      this.applyCityState(r.state);
      this.newCityName = '';
      this.geoSearchRows = [];
      this.hintText = '';
      router.back();
      return;
    }
    const prevErr = r.errorMessage;
    void this.runLookupOnceForAdd(this.newCityName.trim(), prevErr);
  }

  private async runLookupOnceForAdd(q: string, prevErr: string): Promise<void> {
    if (q.length === 0) {
      this.hintText = prevErr;
      return;
    }
    const gen = ++this.lookupGeneration;
    const list = await lookupCities(q);
    if (gen !== this.lookupGeneration) {
      return;
    }
    if (list.length === 1) {
      const h = list[0];
      const s = this.cityVM.addCityFromGeo(h.id, h.name, h.name);
      this.applyCityState(s);
      this.newCityName = '';
      this.geoSearchRows = [];
      this.hintText = '';
      router.back();
      return;
    }
    this.geoSearchRows = list.map((h: GeoLookupHit): GeoSearchRowView => {
      const row: GeoSearchRowView = {
        hit: h,
        emoji: '',
        conditionText: '',
        rangeText: '…'
      };
      return row;
    });
    this.geoLoading = false;
    const addIds: string[] = [];
    for (let j = 0; j < list.length; j++) {
      addIds.push(list[j].id);
    }
    void this.loadGeoSearchRowSummaries(addIds);
    if (list.length === 0) {
      this.hintText =
        '未搜索到结果。请尝试「长沙」「岳麓区」等；若控制台未开通 GeoAPI 或 Key 无权限，也会无结果。';
    } else {
      this.hintText = '请在下方的「全部城市」中点选精确位置（与华为天气一致）';
    }
  }

  private onPickGeoHit(hit: GeoLookupHit): void {
    const s = this.cityVM.addCityFromGeo(hit.id, hit.name, hit.name);
    this.applyCityState(s);
    this.newCityName = '';
    this.geoSearchRows = [];
    this.hintText = '';
    router.back();
  }

  private onHistoryPick(item: SearchHistoryItem): void {
    const s = this.cityVM.addCityFromGeo(item.locationId, item.name, item.name);
    this.applyCityState(s);
    router.back();
  }

  private clearHistory(): void {
    this.cityVM.clearSearchHistory();
    this.searchHistory = [];
  }

  @Builder
  sectionTitleBar(title: string, rightLabel: string, onRight: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF');
      Blank().layoutWeight(1);
      if (rightLabel.length > 0) {
        Text(rightLabel)
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.55)')
          .onClick(() => {
            onRight();
          });
      }
    }
    .width('100%')
    .margin({ bottom: 12 });
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor('#FFFFFF')
          .padding({ right: 12, top: 4, bottom: 4 })
          .onClick(() => {
            router.back();
          });
        Text('搜索城市')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1);
      }
      .width('100%')
      .padding({ top: 8, bottom: 4 });

      Row() {
        Text('⌕')
          .fontSize(18)
          .fontColor('rgba(255,255,255,0.55)')
          .margin({ left: 4, right: 8 });
        TextInput({
          placeholder: '搜索城市（中文 / 拼音）',
          text: this.newCityName
        })
          .placeholderColor('rgba(255,255,255,0.45)')
          .fontColor('#F0F4F8')
          .caretColor('#FFFFFF')
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .height(40)
          .onChange((v: string) => {
            this.newCityName = v;
            if (this.hintText.length > 0) {
              this.hintText = '';
            }
            this.scheduleGeoSearch(v);
          })
          .onSubmit(() => {
            this.onAddClick();
          });
        Text('添加')
          .fontSize(14)
          .fontColor('#7CB8FF')
          .padding({ left: 10, right: 6 })
          .onClick(() => {
            this.onAddClick();
          });
      }
      .width('100%')
      .padding({ left: 12, right: 8, top: 6, bottom: 6 })
      .borderRadius(22)
      .backgroundColor('rgba(255,255,255,0.12)')
      .margin({ top: 8, bottom: 8 });

      if (this.hintText.length > 0) {
        Text(this.hintText)
          .fontSize(12)
          .fontColor('#FFB4A8')
          .width('100%')
          .margin({ bottom: 8 });
      }

      Scroll() {
        Column({ space: 14 }) {
          if (this.newCityName.trim().length > 0) {
            Column() {
              this.sectionTitleBar('全部城市', '', () => {});
              if (this.geoLoading) {
                Text('正在搜索…')
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.55)')
                  .width('100%');
              } else if (this.geoSearchRows.length === 0) {
                Text('无匹配城市，请修改关键词')
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.45)')
                  .width('100%');
              } else {
                ForEach(
                  this.geoSearchRows,
                  (row: GeoSearchRowView, idx: number) => {
                    Row() {
                      Column() {
                        Text(row.hit.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#FFFFFF')
                          .width('100%');
                        Text(
                          row.hit.adm1.length > 0 || row.hit.adm2.length > 0
                            ? `${row.hit.adm2}，${row.hit.adm1}，${row.hit.country}`
                            : '内置城市列表匹配 · 点选后查看天气'
                        )
                          .fontSize(12)
                          .fontColor('rgba(255,255,255,0.55)')
                          .width('100%')
                          .margin({ top: 6 });
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start);

                      Column() {
                        Text(row.emoji.length > 0 ? row.emoji : ' ')
                          .fontSize(22)
                          .textAlign(TextAlign.Center)
                          .width('100%');
                        Text(row.conditionText.length > 0 ? row.conditionText : row.rangeText === '…' ? ' ' : '—')
                          .fontSize(11)
                          .fontColor('rgba(255,255,255,0.6)')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .textAlign(TextAlign.Center)
                          .width('100%');
                      }
                      .width(76)
                      .alignItems(HorizontalAlign.Center)
                      .margin({ left: 6 });

                      Text(row.rangeText.length > 0 ? row.rangeText : '…')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('rgba(255,255,255,0.92)')
                        .textAlign(TextAlign.End)
                        .margin({ left: 6 });
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .padding({ top: 14, bottom: 14 })
                    .borderWidth({ bottom: idx < this.geoSearchRows.length - 1 ? 1 : 0 })
                    .borderColor('rgba(255,255,255,0.08)')
                    .onClick(() => {
                      this.onPickGeoHit(row.hit);
                    });
                  },
                  (row: GeoSearchRowView, idx: number) => `${row.hit.id}_${idx}_${row.rangeText}_${row.conditionText}`
                );
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(20)
            .backgroundColor('rgba(255,255,255,0.1)')
            .border({ width: 1, color: 'rgba(255,255,255,0.12)' });
          }

          Column() {
            this.sectionTitleBar('搜索历史', this.searchHistory.length > 0 ? '清空' : '', () => {
              this.clearHistory();
            });
            if (this.searchHistory.length === 0) {
              Text('暂无搜索记录')
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.45)')
                .width('100%');
            } else {
              Flex({
                direction: FlexDirection.Row,
                wrap: FlexWrap.Wrap,
                alignItems: ItemAlign.Center
              }) {
                ForEach(
                  this.searchHistory,
                  (item: SearchHistoryItem, idx: number) => {
                    Text(item.name)
                      .fontSize(13)
                      .fontColor('#F0F4F8')
                      .padding({
                        left: 14,
                        right: 14,
                        top: 8,
                        bottom: 8
                      })
                      .margin({ right: 8, bottom: 8 })
                      .borderRadius(18)
                      .backgroundColor('rgba(255,255,255,0.14)')
                      .border({ width: 1, color: 'rgba(255,255,255,0.1)' })
                      .onClick(() => {
                        this.onHistoryPick(item);
                      });
                  },
                  (item: SearchHistoryItem, idx: number) => `${item.locationId}_${idx}`
                );
              }
              .width('100%');
            }
          }
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .backgroundColor('rgba(255,255,255,0.1)')
          .border({ width: 1, color: 'rgba(255,255,255,0.12)' });

          if (this.newCityName.trim().length === 0) {
            Column() {
              this.sectionTitleBar('热门城市', '', () => {});
              ForEach(this.hotCityRows, (row: HotCityRowView, index: number) => {
                Row() {
                  Text(`${row.rank}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.rankAccentColor(row.rank - 1))
                    .width(28)
                    .textAlign(TextAlign.Center);
                  Column() {
                    Text(row.label)
                      .fontSize(16)
                      .fontColor('#FFFFFF');
                    Text('轻点添加至我的城市')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.45)')
                      .margin({ top: 4 });
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);

                  Column() {
                    Text(row.emoji.length > 0 ? row.emoji : ' ')
                      .fontSize(20)
                      .textAlign(TextAlign.Center)
                      .width('100%');
                    Text(row.conditionText.length > 0 ? row.conditionText : row.rangeText === '…' ? ' ' : '—')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.6)')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.Center)
                      .width('100%');
                  }
                  .width(72)
                  .alignItems(HorizontalAlign.Center)
                  .margin({ left: 4 });

                  Text(row.rangeText.length > 0 ? row.rangeText : '…')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('rgba(255,255,255,0.9)')
                    .textAlign(TextAlign.End)
                    .margin({ left: 6 });
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })
                .borderWidth({ bottom: index < this.hotCityRows.length - 1 ? 1 : 0 })
                .borderColor('rgba(255,255,255,0.08)')
                .onClick(() => {
                  const r = this.cityVM.addCity(row.label);
                  if (!r.errorMessage) {
                    this.applyCityState(r.state);
                    router.back();
                  } else {
                    this.hintText = r.errorMessage;
                  }
                });
              }, (row: HotCityRowView, index: number) => `hot_${row.locationId}_${row.rangeText}_${row.conditionText}_${index}`);
            }
            .width('100%')
            .padding(16)
            .borderRadius(20)
            .backgroundColor('rgba(255,255,255,0.1)')
            .border({ width: 1, color: 'rgba(255,255,255,0.12)' });
          }

          Column() {
            this.sectionTitleBar('我的城市', '', () => {});
            if (this.myCityRows.length === 0) {
              Text('暂无城市')
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.45)');
            } else {
              ForEach(
                this.myCityRows,
                (row: MyCityRowView, idx: number) => {
                  Row() {
                    Column() {
                      Text(row.entry.label)
                        .fontSize(16)
                        .fontColor('#FFFFFF');
                      if (row.entry.locationId === this.currentLocationId) {
                        Text('当前显示')
                          .fontSize(11)
                          .fontColor('rgba(126,200,255,0.95)')
                          .margin({ top: 4 });
                      }
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Column() {
                      Text(row.emoji.length > 0 ? row.emoji : ' ')
                        .fontSize(20)
                        .textAlign(TextAlign.Center)
                        .width('100%');
                      Text(row.conditionText.length > 0 ? row.conditionText : row.rangeText === '…' ? ' ' : '—')
                        .fontSize(11)
                        .fontColor('rgba(255,255,255,0.6)')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .textAlign(TextAlign.Center)
                        .width('100%');
                    }
                    .width(68)
                    .alignItems(HorizontalAlign.Center)
                    .margin({ right: 4 });

                    Text(row.rangeText.length > 0 ? row.rangeText : '…')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('rgba(255,255,255,0.9)')
                      .margin({ right: 8 });

                    Text('设为当前')
                      .fontSize(13)
                      .fontColor('#E8EEF5')
                      .padding({
                        left: 12,
                        right: 12,
                        top: 6,
                        bottom: 6
                      })
                      .borderRadius(16)
                      .backgroundColor('rgba(255,255,255,0.16)')
                      .margin({ right: 8 })
                      .onClick(() => {
                        const next = this.cityVM.setCurrentCity(row.entry.locationId);
                        this.applyCityState(next);
                        router.back();
                      });

                    Text('删除')
                      .fontSize(13)
                      .fontColor('rgba(255,180,170,0.95)')
                      .padding({
                        left: 12,
                        right: 12,
                        top: 6,
                        bottom: 6
                      })
                      .borderRadius(16)
                      .backgroundColor('rgba(255,255,255,0.08)')
                      .onClick(() => {
                        const next = this.cityVM.removeCity(row.entry.locationId);
                        this.applyCityState(next);
                      });
                  }
                  .width('100%')
                  .padding({ top: 14, bottom: 14 })
                  .borderWidth({ bottom: idx < this.myCityRows.length - 1 ? 1 : 0 })
                  .borderColor('rgba(255,255,255,0.08)');
                },
                (row: MyCityRowView, idx: number) =>
                  `${row.entry.locationId}_${row.rangeText}_${row.conditionText}_${idx}`
              );
            }
          }
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .backgroundColor('rgba(255,255,255,0.1)')
          .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
          .margin({ bottom: 24 });
        }
        .width('100%');
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring);
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 12 })
    .linearGradient({
      angle: 165,
      colors: [['#7A8B9E', 0.0], ['#5A6A7A', 0.5], ['#3D4A56', 1.0]]
    })
    .backgroundColor('#6D7E90')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}
