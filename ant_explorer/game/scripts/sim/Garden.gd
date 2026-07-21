class_name Garden
extends RefCounted
## Colony food engine: leaf deposits raise health; waste/decay lower it.

signal health_changed(health: float)

var health: float = 0.75
var deposits_this_window: int = 0
var waste: float = 0.0

func setup(initial: float = 0.75) -> void:
	health = clampf(initial, 0.0, 1.0)

func deposit_leaf(amount: float = -1.0) -> void:
	var gain: float = amount if amount > 0.0 else Config.data.garden_deposit_gain
	health = clampf(health + gain, 0.0, 1.0)
	deposits_this_window += 1
	waste = maxf(0.0, waste - gain * 0.25)
	health_changed.emit(health)

func tend(amount: float = 0.008) -> void:
	health = clampf(health + amount, 0.0, 1.0)
	health_changed.emit(health)

func add_waste(amount: float = 0.01) -> void:
	waste += amount

func clear_waste(amount: float = 0.02) -> void:
	waste = maxf(0.0, waste - amount)
	health = clampf(health + amount * 0.15, 0.0, 1.0)
	health_changed.emit(health)

func tick_decay() -> void:
	var decay: float = Config.data.garden_waste_decay
	health = clampf(health - decay * 0.35 - waste * 0.002, 0.05, 1.0)
	waste = maxf(0.0, waste - decay * 0.1)
	health_changed.emit(health)
