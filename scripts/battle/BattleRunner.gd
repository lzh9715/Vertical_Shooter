extends Node
class_name BattleRunner

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal battle_finished()

@export var spawner: EnemySpawner

var _pending_entries := 0     # 本波还有几条 entry 没触发

## 按顺序播放一组波次；全部打完发 battle_finished
func run(waves: Array[WaveData]) -> void:
	if waves.is_empty():
		push_warning("没有配置波次")
		battle_finished.emit()
		return

	var total := waves.size()
	for i in range(total):
		wave_started.emit(i + 1, total)
		await _run_wave(waves[i])
		wave_cleared.emit(i + 1)

		if i < total - 1:
			await get_tree().create_timer(waves[i].gap_after, false).timeout

	battle_finished.emit()

func _run_wave(wave: WaveData) -> void:
	_pending_entries = 0

	for entry in wave.entries:
		if entry == null or entry.spawn == null:
			continue
		_pending_entries += 1
		_fire(entry)

	if wave.clear_to_advance:
		await _wait_clear()
	else:
		await get_tree().create_timer(wave.gap_after, false).timeout

## entry 的延迟是「相对本波开始」，所以这里各自起协程，互不等待
func _fire(entry: WaveEntry) -> void:
	if entry.delay > 0.0:
		await get_tree().create_timer(entry.delay, false).timeout
	if not is_instance_valid(spawner) or not is_inside_tree():
		return
	spawner.spawn(entry.spawn)
	_pending_entries = maxi(_pending_entries - 1, 0)

## 等“本波所有 entry 都已触发”且“场上敌人清空”
func _wait_clear() -> void:
	await get_tree().process_frame

	var waited := 0.0
	while spawner.alive_count() > 0 or _pending_entries > 0:
		await get_tree().create_timer(0.15, false).timeout
		waited += 0.15
		if waited > 90.0:
			push_warning("波次等待超时，强制推进")
			return