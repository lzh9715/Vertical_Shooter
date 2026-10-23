# 横版飞行射击（Godot 4.7）

Roguelike 横版弹幕射击原型：从左到右推进，玩家在左侧，敌人主要从右侧进入。

## 运行

1. 用 Godot 4.7+ 打开 `project.godot`
2. F5 运行主菜单
3. 单独调试某个场景时用 F6

## 目录结构

```text
scenes/
  battle/     战斗场景
  boss/       Boss 基础场景
  enemies/    小怪 / 精英 / 敌方子弹
  player/     玩家 / 玩家子弹
  map/        横版地图
  shop/       商店
  ui/         主菜单、暂停、设置、事件、奖励、结算等

scripts/
  core/       自动加载与全局工具（GameFlow、EventBus、Settings、音频、转场等）
  battle/     战斗主脚本与波次运行器
  boss/       Boss 基类
  enemies/    小怪、精英、敌方子弹
  player/     玩家与玩家子弹
  map/        地图数据与生成器
  shop/       商店逻辑
  spawn/      出怪基类与 Spawner

data/
  core/             敌人/波次/难度/定价等基础资源类
  enemies/          敌人数据
  waves/            波次与测试波次
  attacks/          攻击序列
  bullet_patterns/  弹幕模式脚本
  bullet_templates/ 弹型资源
  spells/           法杖数据
  boss/             Boss 数据与阶段
  event/            事件
  reward/           奖励关
  shop/             商品模型
  shapes/           阵型
  movement/         移动模式
  elite_movement/   精英移动

debug/        手动调试场景（BossTest、EventTest、MapDebug、SettingsTest）
```

## 操作

- 移动：WASD / 方向键
- 射击：自动向右
- 暂停：Esc
- 鼠标跟随已移除

## 当前内容

- 横版固定宽度 2560，世界高度 2160（摄像机上下跟随）
- 小怪 / 精英 / Boss 框架
- 奖励关、事件节点、商店、结算
- 设置：窗口大小、全屏、垂直同步、音量
- 场景淡入淡出、伤害数字、音频调用点

## 调试场景

- `debug/BossTest.tscn`：Boss 阶段与偷取
- `debug/EventTest.tscn`：事件选项
- `debug/MapDebug.tscn`：地图生成压力测试
- `debug/SettingsTest.tscn`：设置读写
