import type { LifeIndex } from '../model/WeatherState';

@Component
export struct LifeIndexCard {
  @Prop lifeIndex: LifeIndex | undefined;
  @Prop isDarkMode: boolean = false;
  @Prop huaweiStyle: boolean = false;

  build() {
    Column() {
      Text('生活指数')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.huaweiStyle ? '#FFFFFF' : Color.Black)
        .opacity(this.huaweiStyle ? 0.95 : 1)
        .margin({ bottom: 12 });

      if (this.lifeIndex) {
        Row() {
          Text('穿衣')
            .fontSize(14)
            .fontColor(this.huaweiStyle ? '#B8C4D0' : Color.Black)
            .opacity(this.huaweiStyle ? 0.88 : 0.75)
            .width(72);
          Text(this.lifeIndex.dressing)
            .fontSize(14)
            .fontColor(this.huaweiStyle ? '#F0F4F8' : Color.Black)
            .layoutWeight(1);
        }.margin({ bottom: 10 });

        Row() {
          Text('紫外线')
            .fontSize(14)
            .fontColor(this.huaweiStyle ? '#B8C4D0' : Color.Black)
            .opacity(this.huaweiStyle ? 0.88 : 0.75)
            .width(72);
          Text(`${this.lifeIndex.uvIndex} · ${this.lifeIndex.uvDesc}`)
            .fontSize(14)
            .fontColor(this.huaweiStyle ? '#F0F4F8' : Color.Black)
            .layoutWeight(1);
        }.margin({ bottom: 10 });

        Row() {
          Text('空气')
            .fontSize(14)
            .fontColor(this.huaweiStyle ? '#B8C4D0' : Color.Black)
            .opacity(this.huaweiStyle ? 0.88 : 0.75)
            .width(72);
          Text(this.lifeIndex.airQualityText)
            .fontSize(14)
            .fontColor(this.huaweiStyle ? '#F0F4F8' : Color.Black)
            .layoutWeight(1);
        };
      } else {
        Text('加载中...')
          .fontColor(this.huaweiStyle ? '#D8DEE6' : Color.Black)
          .opacity(0.75);
      }
    }
    .padding(16)
    .borderRadius(20)
    .backgroundColor(
      this.huaweiStyle ? 'rgba(255,255,255,0.14)' : (this.isDarkMode ? '#1F2A3A' : '#F3F6FB')
    )
    .border({
      width: this.huaweiStyle ? 1 : 0,
      color: 'rgba(255,255,255,0.12)'
    });
  }
}

