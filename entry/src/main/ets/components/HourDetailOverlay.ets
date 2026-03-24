import type { HourlyForecast } from '../model/WeatherState';

function tipForHour(item: HourlyForecast): string {
  if (item.precipitationProbability >= 60) {
    return '该时段降水概率较高，外出建议携带雨具，注意路面湿滑。';
  }
  if (item.precipitationProbability >= 30) {
    return '该时段有可能出现降水，请关注临近预报并适当准备。';
  }
  if (item.conditionText.includes('雨')) {
    return '预报为降雨时段，尽量减少长时间户外活动。';
  }
  if (item.conditionText.includes('晴')) {
    return '天气较晴朗，紫外线可能偏强，注意补水与防晒。';
  }
  return '可结合当日整体趋势安排出行；以下为该小时概要信息。';
}

@Component
export struct HourDetailOverlay {
  @Prop item: HourlyForecast = {
    hourLabel: '',
    temperature: 0,
    conditionText: '',
    precipitationProbability: 0
  };
  @Prop cityDisplayName: string = '';
  /** 父组件传入关闭回调 */
  onClose: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.52)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.onClose();
        });

      Column({ space: 14 }) {
        Text('逐小时详情')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.65)')
          .width('100%');

        Text(`${this.cityDisplayName} · ${this.item.hourLabel}`)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .width('100%');

        Text(`${this.item.temperature}°C`)
          .fontSize(40)
          .fontWeight(FontWeight.Lighter)
          .fontColor('#FFFFFF')
          .margin({ top: 4 });

        Text(this.item.conditionText)
          .fontSize(16)
          .fontColor('#E8EEF5')
          .width('100%');

        Row() {
          Text('降水概率')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.7)');
          Text(`${this.item.precipitationProbability}%`)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 });
        }
        .width('100%')
        .margin({ top: 6 });

        Text(tipForHour(this.item))
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.78)')
          .lineHeight(20)
          .width('100%')
          .margin({ top: 10 });

        Button('知道了')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor('#1A2B3C')
          .backgroundColor('#E8EEF5')
          .borderRadius(22)
          .margin({ top: 20 })
          .onClick(() => {
            this.onClose();
          });
      }
      .width('86%')
      .constraintSize({ maxWidth: 400 })
      .padding(22)
      .borderRadius(22)
      .backgroundColor('rgba(38,48,58,0.96)')
      .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
      .alignSelf(ItemAlign.Center)
      .onClick(() => {
        // 阻止点击穿透到遮罩（部分版本需显式消费）
      });
    }
    .width('100%')
    .height('100%')
  }
}
