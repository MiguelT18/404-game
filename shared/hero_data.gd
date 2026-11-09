class_name HeroData
extends Resource

enum AttackType { MELEE, RANGED }

## Ataque básico y las 4 habilidades.
const SLOT_COUNT := 5

@export var id: StringName
@export var display_name: String
@export var attack_type: AttackType
@export var damage_type: AbilityData.DamageType
@export var move_speed: float = 6.0
@export var jump_speed: float = 7.0
@export var max_health: float = 500.0
@export var max_mana: float = 200.0
@export var mana_regen: float = 5.0
@export var armor: float = 0.0
@export var magic_resist: float = 0.0
@export var basic_attack: AbilityData
@export var abilities: Array[AbilityData] = []


## El slot 0 es el ataque básico. Devuelve null si el slot no existe.
func ability(slot: int) -> AbilityData:
	if slot == 0:
		return basic_attack
	return abilities[slot - 1] if slot >= 1 and slot <= abilities.size() else null
