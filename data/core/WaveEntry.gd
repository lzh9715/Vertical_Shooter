extends Resource
class_name WaveEntry

## 一波里的一条“生成指令”：用哪个 SpawnGroup，在本波开始后延迟多久执行。
@export var spawn: SpawnGroup
@export var delay: float = 0.0