extends Node
## 全局事件总线（Autoload）。Boss / 道具 / UI 不互相引用。

## 预留：控制类 debuff（当前版本 Boss 最多两种能力，暂不启用）
signal debuff_requested(kind: StringName, duration: float, strength: float)

## Boss 请求借用玩家法杖，duration 秒后归还
signal steal_spell_requested(duration: float)
signal spell_stolen(spell: SpellData)
signal spell_returned(spell: SpellData)

## Boss 死亡/战斗结束时，强制取消偷取
signal steal_cancelled