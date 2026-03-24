import type { MinuteRainPoint } from '../model/WeatherState';

function intensityToColor(intensity: number, onDark: boolean): string {
  if (onDark) {
    if (intensity <= 0) return 'rgba(255,255,255,0.12)';
    if (intensity < 20) return 'rgba(147,197,255,0.45)';
    if (intensity < 40) return 'rgba(120,180,255,0.65)';
    if (intensity < 60) return 'rgba(90,160,255,0.85)';
    if (intensity < 80) return '#7CB8FF';
    return '#B8D9FF';
  }
  if (intensity <= 0) return '#E6EAF2';
  if (intensity < 20) return '#CFE0FF';
  if (intensity < 40) return '#A6C8FF';
  if (intensity < 60) return '#6FA6FF';
  if (intensity < 80) return '#FF9E3D';
  return '#FF3B30';
}

function intensityToHeight(intensity: number): number {
  // 柱状高度映射（单位：vp）
  const minH = 6;
  const maxH = 48;
  const ratio = Math.max(0, Math.min(1, intensity / 100));
  return Math.round(minH + ratio * (maxH - minH));
}

@Component
export struct MinuteRainBarHeat {
  @Prop points: MinuteRainPoint[] = [];
  @Prop isDarkMode: boolean = false;
  @Prop huaweiStyle: boolean = false;

  build() {
    Column({ space: 12 }) {
      Text('分钟级降水')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.huaweiStyle ? '#FFFFFF' : Color.Black)
        .opacity(this.huaweiStyle ? 0.92 : 0.8);

      Scroll() {
        Row() {
          ForEach(
            this.points,
            (p: MinuteRainPoint, index: number) => {
              Column() {
                Blank()
                  .width(8)
                  .height(intensityToHeight(p.intensity))
                  .backgroundColor(intensityToColor(p.intensity, this.huaweiStyle))
                  .borderRadius(4);

                if (index % 10 === 0) {
                  Text(p.minuteLabel)
                    .fontSize(10)
                    .fontColor(this.huaweiStyle ? '#D8DEE6' : Color.Black)
                    .opacity(this.huaweiStyle ? 0.75 : 0.65)
                    .width(100)
                    .textAlign(TextAlign.Center);
                } else {
                  Blank().height(14);
                }
              }
              .width(16);
            },
            (p: MinuteRainPoint) => p.minuteLabel
          );
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
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

