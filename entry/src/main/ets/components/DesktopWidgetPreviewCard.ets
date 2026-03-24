import type { HourlyForecast } from '../model/WeatherState';

@Component
export struct DesktopWidgetPreviewCard {
  @Prop cityName: string = '深圳';
  @Prop currentTemperature: number = 0;
  @Prop conditionText: string = '多云';
  @Prop highLowText: string = '--/--°C';
  @Prop updatedText: string = '--:--';
  @Prop hourly: HourlyForecast[] = [];

  private hourLabel(idx: number): string {
    return this.hourly.length > idx ? this.hourly[idx].hourLabel : '--:--';
  }

  private hourTemp(idx: number): string {
    if (this.hourly.length <= idx) {
      return '--°';
    }
    return `${Math.round(this.hourly[idx].temperature)}°`;
  }

  build() {
    Column({ space: 8 }) {
      Text('桌面天气卡片预览')
        .fontSize(13)
        .fontColor('#E9F1FB')
        .opacity(0.9)
        .width('100%');

      Column({ space: 8 }) {
        Row() {
          Row({ space: 8 }) {
            Text(`${Math.round(this.currentTemperature)}°C`)
              .fontSize(34)
              .fontWeight(FontWeight.Medium)
              .fontColor('#F6FAFF');
            Text('☁️')
              .fontSize(22);
          }
          Column({ space: 2 }) {
            Text(this.cityName)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor('#F6FAFF');
            Text(this.highLowText)
              .fontSize(13)
              .fontColor('#DBE8F6');
            Text(this.conditionText)
              .fontSize(13)
              .fontColor('#DBE8F6');
          }
          .alignItems(HorizontalAlign.End);
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween);

        Row({ space: 8 }) {
          this.HourItem(this.hourLabel(0), this.hourTemp(0));
          this.HourItem(this.hourLabel(1), this.hourTemp(1));
          this.HourItem(this.hourLabel(2), this.hourTemp(2));
          this.HourItem(this.hourLabel(3), this.hourTemp(3));
        }
        .width('100%');

        Text(`更新 ${this.updatedText}`)
          .fontSize(12)
          .fontColor('#C8DAEE')
          .opacity(0.92)
          .width('100%');
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .backgroundColor('#7089A3C0')
      .borderRadius(16);
    }
    .width('100%');
  }

  @Builder
  private HourItem(timeText: string, tempText: string) {
    Column({ space: 4 }) {
      Text(timeText)
        .fontSize(11)
        .fontColor('#D8E5F5');
      Text(tempText)
        .fontSize(14)
        .fontColor('#F6FAFF');
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start);
  }
}
