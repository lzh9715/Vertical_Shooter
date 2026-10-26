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
  backpack/   网格背包
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
  inventory/  背包、法杖、装备数据模型

data/
  items/            物品定义与词条
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
- 地图打开背包：B 或右上角「背包」按钮
- 战斗中不能打开背包
- 背包右侧：点击法杖 1/2 切换编辑对象，点「编辑法术」打开法术卡装配面板
- 战斗中按 Q 切换已装备的两把法杖

## 当前内容

- 横版固定宽度 2560，世界高度 2160（摄像机上下跟随）
- 小怪 / 精英 / Boss 框架
- 奖励关、事件节点、商店、结算
- 5×3 商店：宝石/杖身、帽子/袍子/配饰、法术卡三行分类与保底
- 商店购买进背包，背包满阻止购买；出售返还 50% 价值
- 10×6 网格背包、拖拽、溢出格、垃圾桶、装备槽
- 节点进入前的溢出提醒：第一次强制整理，第二次可确认丢弃溢出
- 两把法杖装配、宝石/杖身替换、法术卡独立装配面板
- 设置：窗口大小、全屏、垂直同步、音量
- 场景淡入淡出、伤害数字、音频调用点

## 调试场景

- `debug/BackpackTest.tscn`：背包拖拽/溢出/垃圾桶体验
- `debug/SpellTest.tscn`：法术测试场，木桩会按精英落位后的方式上下移动
- `debug/WandBattleTest.tscn`：法杖卡组自动射击与 Q 切换测试
- `debug/CastSimTest.tscn`：法力账本、多重施法与透支模拟测试
- `debug/BossTest.tscn`：Boss 阶段与偷取
- `debug/EventTest.tscn`：事件选项
- `debug/MapDebug.tscn`：地图生成压力测试
- `debug/SettingsTest.tscn`：设置读写

## 回归测试

使用 Godot 4.7，在项目根目录执行：

```bash
python3 tests/run_regressions.py --godot /path/to/Godot
```

也可以通过 `GODOT_BIN` 指定引擎路径；引擎已在 PATH 中时直接运行 `python3 tests/run_regressions.py`。
脚本会创建临时项目副本、导入资源，再运行 `tests/p1_regressions.gd`，覆盖单次击杀奖励、重叠碰撞与穿透上限、爆炸重复回调、清关和死亡的竞态、连续节点、通关重开及淡入期间的场景请求。断言失败、脚本错误或超时均以非零退出码结束。
