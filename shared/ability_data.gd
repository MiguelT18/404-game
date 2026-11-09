class_name AbilityData
extends Resource
## Una habilidad es una pieza reutilizable (`kind`) con sus valores.

enum Kind { CONE, PROJECTILE, AREA, DASH, SHIELD, ZONE, BLINK, LEAP, BEAM }
enum DamageType { PHYSICAL, MAGIC }

@export var id: StringName
@export var display_name: String
@export var kind: Kind
@export var damage_type: DamageType
## En las zonas es el daño de cada pulso.
@export var damage: float = 0.0
@export var mana_cost: float = 0.0
@export var cooldown: float = 1.0
## Distancia máxima. En un área, 0 la centra en quien la lanza.
@export var reach: float = 0.0
@export var radius: float = 0.0
## Apertura total del cono, en grados.
@export var angle: float = 90.0
@export var speed: float = 0.0
## Carga antes de ejecutarse, sin poder moverse.
@export var cast_delay: float = 0.0
## Vida de una zona o de un escudo, o tiempo en el aire de un salto.
@export var duration: float = 0.0
## Fracción de velocidad que se quita al objetivo.
@export var slow: float = 0.0
@export var slow_duration: float = 0.0
@export var stun: float = 0.0
@export var shield: float = 0.0
## Color de sus efectos en el cliente. Transparente usa el del tipo de daño.
@export var fx_color := Color(0, 0, 0, 0)
