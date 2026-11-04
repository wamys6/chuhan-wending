## 确定性随机数（xorshift32）
##
## 为什么要自己写：迁移期的「等价性测试」要求 GDScript 与 JS 版在同一 seed 下
## 产生完全相同的牌序，从而逐步比对状态。Godot 自带 RNG 算法与 JS 对不上，
## 所以两边共用这一个实现。游戏发布后可以换回 RandomNumberGenerator。
class_name Rng
extends RefCounted

var state: int = 1

func _init(seed_value: int = 1) -> void:
	state = seed_value if seed_value != 0 else 1

## 推进一次，返回 [0, 1) 的浮点
func next_float() -> float:
	var x := state
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	state = x
	return float(x) / 4294967296.0

func next_int(n: int) -> int:
	return int(floor(next_float() * float(n)))
