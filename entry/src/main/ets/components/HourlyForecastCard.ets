import type { HourlyForecast } from '../model/WeatherState';
import { conditionTextToEmoji } from '../services/WeatherConditionVisual';

@Component
export struct HourlyForecastCard {
  @Prop item: HourlyForecast;
  @Prop isDarkMode: boolean = false;
  /** 与首页渐变背景配套的半透明卡片 */
  @Prop huaweiStyle: boolean = false;

  build() {
    Column() {
      Text(this.item.hourLabel)
        .fontSize(12)
        .fontColor(this.huaweiStyle ? '#E8EEF5' : Color.Black)
        .opacity(this.huaweiStyle ? 0.88 : 0.8);

      if (this.huaweiStyle) {
        Text(conditionTextToEmoji(this.item.conditionText))
          .fontSize(28)
          .margin({ top: 6, bottom: 2 });
      }

      Text(`${this.item.temperature}°C`)
        .fontSize(17)
        .fontColor(this.huaweiStyle ? '#FFFFFF' : Color.Black)
        .margin({ top: 8 });

      Text(this.item.conditionText)
        .fontSize(11)
        .fontColor(this.huaweiStyle ? '#D8DEE6' : Color.Black)
        .opacity(0.92)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text(`降水 ${this.item.precipitationProbability}%`)
        .fontSize(11)
        .fontColor(this.huaweiStyle ? '#B8C4D0' : Color.Black)
        .opacity(this.huaweiStyle ? 0.85 : 0.7)
        .margin({ top: 6 });
    }
    .padding(14)
    .width(96)
    .borderRadius(20)
    .backgroundColor(
      this.huaweiStyle ? 'rgba(255,255,255,0.16)' : (this.isDarkMode ? '#1F2A3A' : '#F3F6FB')
    )
    .border({
      width: this.huaweiStyle ? 1 : 0,
      color: 'rgba(255,255,255,0.14)'
    });
  }
}

