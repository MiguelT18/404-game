class_name CombatState
extends RefCounted
## Vida, maná y efectos de cualquier objetivo. Sin nodos, para poder probarlo.

var max_health := 0.0
var health := 0.0
var max_mana := 0.0
var mana := 0.0
var mana_regen := 0.0
var armor := 0.0
var magic_resist := 0.0
var shield := 0.0
var cooldowns := PackedFloat32Array()

var _shield_left := 0.0
var _slow := 0.0
var _slow_left := 0.0
var _stun_left := 0.0


static func for_hero(hero: HeroData) -> CombatState:
	var state := CombatState.new()
	state.max_health = hero.max_health
	state.max_mana = hero.max_mana
	state.mana_regen = hero.mana_regen
	state.armor = hero.armor
	state.magic_resist = hero.magic_resist
	state.cooldowns.resize(HeroData.SLOT_COUNT)
	state.reset()
	return state


static func for_dummy(dummy: DummyData) -> CombatState:
	var state := CombatState.new()
	state.max_health = dummy.max_health
	state.armor = dummy.armor
	state.magic_resist = dummy.magic_resist
	state.reset()
	return state


func reset() -> void:
	health = max_health
	mana = max_mana
	shield = 0.0
	cooldowns.fill(0.0)
	_shield_left = 0.0
	_slow_left = 0.0
	_stun_left = 0.0


func is_alive() -> bool:
	return health > 0.0


func is_stunned() -> bool:
	return _stun_left > 0.0


func tick(delta: float) -> void:
	if not is_alive():
		return
	mana = minf(mana + mana_regen * delta, max_mana)
	for slot in cooldowns.size():
		cooldowns[slot] = maxf(cooldowns[slot] - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	_stun_left = maxf(_stun_left - delta, 0.0)
	_shield_left = maxf(_shield_left - delta, 0.0)
	if _shield_left == 0.0:
		shield = 0.0


func can_cast(slot: int, ability: AbilityData) -> bool:
	return is_alive() and not is_stunned() and cooldowns[slot] <= 0.0 and mana >= ability.mana_cost


func spend(slot: int, ability: AbilityData) -> void:
	mana -= ability.mana_cost
	cooldowns[slot] = ability.cooldown


## El escudo absorbe primero. Devuelve el daño tras la mitigación.
func take_damage(amount: float, type: AbilityData.DamageType) -> float:
	var resistance := armor if type == AbilityData.DamageType.PHYSICAL else magic_resist
	var dealt := CombatRules.mitigate(amount, resistance)
	var absorbed := minf(shield, dealt)
	shield -= absorbed
	health = maxf(health - (dealt - absorbed), 0.0)
	return dealt


func add_shield(amount: float, duration: float) -> void:
	shield = maxf(shield, amount)
	_shield_left = maxf(_shield_left, duration)


func apply_slow(amount: float, duration: float) -> void:
	_slow = amount if _slow_left == 0.0 else maxf(_slow, amount)
	_slow_left = maxf(_slow_left, duration)


func apply_stun(duration: float) -> void:
	_stun_left = maxf(_stun_left, duration)


## Multiplica la velocidad: 0 si no puede moverse.
func move_factor() -> float:
	if not is_alive() or is_stunned():
		return 0.0
	return 1.0 - _slow if _slow_left > 0.0 else 1.0
