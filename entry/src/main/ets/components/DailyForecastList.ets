import type { DailyForecast } from '../model/WeatherState';
import { conditionTextToEmoji } from '../services/WeatherConditionVisual';

@Component
export struct DailyForecastList {
  @Prop daily: DailyForecast[] = [];
  @Prop huaweiStyle: boolean = false;

  build() {
    Column({ space: 0 }) {
      Text('多日预报')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.huaweiStyle ? '#FFFFFF' : Color.Black)
        .opacity(this.huaweiStyle ? 0.95 : 1)
        .width('100%')
        .margin({ bottom: 12 });

      Column({ space: 14 }) {
        ForEach(this.daily, (item: DailyForecast) => {
          Row() {
            Text(item.dateLabel)
              .fontSize(14)
              .fontColor(this.huaweiStyle ? '#E8EEF5' : Color.Black)
              .width(52);

            if (this.huaweiStyle) {
              Text(conditionTextToEmoji(item.conditionText))
                .fontSize(22)
                .width(36)
                .textAlign(TextAlign.Center);
            }

            Text(item.conditionText)
              .fontSize(14)
              .fontColor(this.huaweiStyle ? '#D8DEE6' : Color.Black)
              .opacity(this.huaweiStyle ? 0.92 : 0.8)
              .layoutWeight(1)
              .margin({ left: this.huaweiStyle ? 6 : 10, right: 10 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Text(`${item.lowTemperature}~${item.highTemperature}°C`)
              .fontSize(14)
              .fontColor(this.huaweiStyle ? '#FFFFFF' : Color.Black)
              .opacity(this.huaweiStyle ? 0.95 : 0.9);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);
        }, (item: DailyForecast) => item.dateLabel);
      }
    }
    .padding(16)
    .borderRadius(20)
    .backgroundColor(this.huaweiStyle ? 'rgba(255,255,255,0.14)' : Color.Transparent)
    .border({
      width: this.huaweiStyle ? 1 : 0,
      color: 'rgba(255,255,255,0.12)'
    });
  }
}

