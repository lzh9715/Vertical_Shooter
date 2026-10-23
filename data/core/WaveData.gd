extends Resource
class_name WaveData

## 一波：若干条生成指令 + 波与波之间的节奏。
## 同一个 WaveData 可以给关卡用，也可以塞进无尽池被反复抽到。

@export var entries: Array[WaveEntry] = []

@export_group("节奏")
@export var gap_after: float = 1.5          # 本波清空后，隔多久出下一波（秒）
@export var clear_to_advance: bool = true   # true=清空才推进；false=按时间推进

## 这一波实际会生成几组敌人（调试用）
func group_count() -> int:
	var n := 0
	for e in entries:
		if e != null and e.spawn != null:
			n += 1
	return n