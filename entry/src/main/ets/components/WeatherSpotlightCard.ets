/** 华为式「精选内容」占位：左文右渐变图块，增强页面图案感 */
@Component
export struct WeatherSpotlightCard {
  @Prop huaweiStyle: boolean = true;

  build() {
    if (!this.huaweiStyle) {
      Blank().width(0).height(0);
    } else {
      Row() {
        Column({ space: 8 }) {
          Text('🔔 气象速览')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.72)');
          Text('#今日天气与生活提示')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF');
          Text('降水、紫外线与穿衣建议见下方卡片')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.58)')
            .maxLines(2);
          Text('查看详情 →')
            .fontSize(12)
            .fontColor('#B8D9FF')
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center);

        Column() {
          Column()
            .width(108)
            .height(88)
            .borderRadius(16)
            .linearGradient({
              angle: 135,
              colors: [
                ['#FFD29B', 0.0],
                ['#8EC5FC', 0.55],
                ['#6B9BD1', 1.0]
              ]
            });
        }
        .justifyContent(FlexAlign.Center);
      }
      .width('100%')
      .padding(16)
      .borderRadius(20)
      .backgroundColor('rgba(255,255,255,0.12)')
      .border({ width: 1, color: 'rgba(255,255,255,0.14)' });
    }
  }
}
