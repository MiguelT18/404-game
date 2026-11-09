extends SkeletonModifier3D
## Gira la muñeca que sujeta el bastón para que puño y bastón queden casi verticales,
## como quien se apoya en él. Los clips son de manos vacías y, sin esto, el bastón
## copiaría cada giro de la muñeca. Al lanzar se relaja para seguir el gesto.

@export var hand_bone := &"RightHand"
## Hueso del bastón: pivote en el puño y la vara a lo largo de su eje Y.
@export var staff_bone := &"Weapon"
@export_range(0.0, 1.0) var upright := 0.85
@export_range(0.0, 1.0) var upright_casting := 0.25
@export var blend_rate := 10.0

## Lo activa `HeroRig` mientras dura un hechizo.
var casting := false
var _amount := 0.85


func _process_modification() -> void:
	var skeleton := get_skeleton()
	var hand := skeleton.find_bone(hand_bone)
	var staff := skeleton.find_bone(staff_bone)
	if hand < 0 or staff < 0:
		return
	var delta := get_process_delta_time()
	var target_amount := upright_casting if casting else upright
	_amount = lerpf(_amount, target_amount, 1.0 - exp(-blend_rate * delta))
	var axis := skeleton.get_bone_global_pose(staff).basis.y.normalized()
	var goal := axis.slerp(Vector3.UP, _amount).normalized()
	if axis.is_equal_approx(goal):
		return
	# Gira la mano sobre la muñeca, así el antebrazo no se separa.
	var turn := Basis(Quaternion(axis, goal))
	var pose := skeleton.get_bone_global_pose(hand)
	skeleton.set_bone_global_pose(hand, Transform3D(turn * pose.basis, pose.origin))
