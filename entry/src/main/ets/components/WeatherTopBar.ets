import type { WeatherStatus } from '../model/WeatherState';
import { CitySwitchBar } from './CitySwitchBar';
import { conditionTextToEmoji } from '../services/WeatherConditionVisual';

@Component
export struct WeatherTopBar {
  @Prop cityName: string = '—';
  @Prop temperature: number = 0;
  @Prop conditionText: string = '—';
  @Prop lastUpdatedText: string = '';
  @Prop status: WeatherStatus = 'loading';
  /** 华为天气式：浅字 + 大字号主温 */
  @Prop huaweiStyle: boolean = false;

  build() {
    Column() {
      CitySwitchBar({ cityName: this.cityName, huaweiStyle: this.huaweiStyle });

      if (this.huaweiStyle) {
        Row() {
          Column() {
            Text(`${this.temperature}°C`)
              .fontSize(72)
              .fontWeight(FontWeight.Lighter)
              .fontColor('#FFFFFF')
              .margin({ top: 16, bottom: 6 });

            Text(this.conditionText)
              .fontSize(17)
              .fontColor('#F0F4F8')
              .opacity(this.status === 'loading' ? 0.6 : 0.95);

            if (this.lastUpdatedText) {
              Text(`更新时间 ${this.lastUpdatedText}`)
                .fontSize(12)
                .fontColor('#D8DEE6')
                .opacity(0.78)
                .margin({ top: 8 });
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1);

          Text(conditionTextToEmoji(this.conditionText))
            .fontSize(80)
            .margin({ top: 8, left: 4 })
            .opacity(0.96);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      } else {
        Text(`${this.temperature}°C`)
          .fontSize(44)
          .fontWeight(FontWeight.Normal)
          .fontColor(Color.Black)
          .margin({ top: 12, bottom: 8 });

        Text(this.conditionText)
          .fontSize(16)
          .fontColor(Color.Black)
          .opacity(this.status === 'loading' ? 0.6 : 0.95);

        if (this.lastUpdatedText) {
          Text(`更新时间 ${this.lastUpdatedText}`)
            .fontSize(12)
            .fontColor(Color.Black)
            .opacity(0.7)
            .margin({ top: 8 });
        }
      }
    }
    .width('100%')
  }
}

