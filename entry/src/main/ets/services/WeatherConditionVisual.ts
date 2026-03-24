/** 首页背景与图标：根据中文现象文案做简单映射（无网络依赖） */

export function conditionTextToEmoji(text: string): string {
  const t = text || '';
  if (t.includes('雷')) {
    return '⛈️';
  }
  if (t.includes('雨')) {
    return '🌧️';
  }
  if (t.includes('雪')) {
    return '❄️';
  }
  if (t.includes('雾') || t.includes('霾')) {
    return '🌫️';
  }
  if (t.includes('云') || t.includes('阴')) {
    return '☁️';
  }
  if (t.includes('晴')) {
    return '☀️';
  }
  return '🌤️';
}

/** linearGradient 的 colors 元组，随现象微调色调 */
export function homeGradientStopsForCondition(conditionText: string): Array<[string, number]> {
  const t = conditionText || '';
  if (t.includes('晴')) {
    return [
      ['#7EB8F0', 0.0],
      ['#4E8AD4', 0.42],
      ['#3A5F8A', 1.0]
    ];
  }
  if (t.includes('雨') || t.includes('雷')) {
    return [
      ['#6B8AA8', 0.0],
      ['#4A6578', 0.48],
      ['#354A5C', 1.0]
    ];
  }
  if (t.includes('雪')) {
    return [
      ['#A8BFD4', 0.0],
      ['#7A92A8', 0.5],
      ['#55667A', 1.0]
    ];
  }
  if (t.includes('云') || t.includes('阴')) {
    return [
      ['#8FA0B2', 0.0],
      ['#6B7C8E', 0.45],
      ['#4E5D6C', 1.0]
    ];
  }
  if (t.includes('雾') || t.includes('霾')) {
    return [
      ['#7A8594', 0.0],
      ['#5C6570', 0.5],
      ['#454C55', 1.0]
    ];
  }
  return [
    ['#8FA0B2', 0.0],
    ['#6B7C8E', 0.45],
    ['#4E5D6C', 1.0]
  ];
}
