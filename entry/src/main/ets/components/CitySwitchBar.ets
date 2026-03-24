import router from '@ohos.router';

@Component
export struct CitySwitchBar {
  @Prop cityName: string = '—';
  @Prop huaweiStyle: boolean = false;

  build() {
    Row() {
      Text(this.cityName)
        .fontSize(this.huaweiStyle ? 22 : 16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.huaweiStyle ? '#FFFFFF' : Color.Black)
        .layoutWeight(1);

      Button(this.huaweiStyle ? '搜索城市' : '切换城市', { type: ButtonType.Normal })
        .fontSize(13)
        .fontColor(this.huaweiStyle ? '#E8EEF5' : Color.Blue)
        .backgroundColor(this.huaweiStyle ? 'rgba(255,255,255,0.18)' : Color.Transparent)
        .borderRadius(18)
        .height(34)
        .onClick(() => {
          router.pushUrl({ url: 'pages/CityListPage' });
        });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }
}

