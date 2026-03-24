import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage) {
    // 应用启动入口：加载首页（要求 `main_pages.json` 中配置 pages/Index）
    windowStage.loadContent('pages/Index', (err) => {
      if (err) {
        console.error(`Failed to load content: ${JSON.stringify(err)}`);
      }

      // phase2：持久化初始化（城市列表/当前城市）
      // 持久化数据建议保持较小（<2KB）以避免性能问题
      const defaultCities = ['深圳', '北京', '上海'];
      PersistentStorage.persistProp('weatherCitiesJson', JSON.stringify(defaultCities));
      PersistentStorage.persistProp('weatherCurrentCityName', defaultCities[0]);
      PersistentStorage.persistProp(
        'weatherCitiesV2Json',
        '[{"locationId":"101280601","label":"深圳"},{"locationId":"101010100","label":"北京"},{"locationId":"101020100","label":"上海"}]'
      );
      PersistentStorage.persistProp('weatherCurrentLocationId', '101280601');
      PersistentStorage.persistProp('weatherSearchHistoryJson', '[]');
    });

    // 保持默认窗口行为，避免部分模拟器下出现启动行为异常。
  }
}

