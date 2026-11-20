class_name Door
extends Node3D
## A hinged interior/exterior door leaf (CLAUDE.md §5: every door is openable). Uses Interactable.

const LEAF_T := 0.045
const OPEN_ANGLE := deg_to_rad(95.0)

var is_open := false
var _hinge: AnimatableBody3D
var _tween: Tween


## pos: bottom-center of the opening (building-local), along_x: the wall runs along local X.
static func make(pos: Vector3, along_x: bool, width: float, mat: Material) -> Door:
	var d := Door.new()
	d.name = "Door"
	d.position = pos
	if not along_x:
		d.rotation.y = PI * 0.5
	var w := maxf(width - 0.04, 0.6)
	var h := minf(InteriorStreamer.DOOR_H - 0.02, 2.11)
	d._hinge = AnimatableBody3D.new()
	d._hinge.collision_layer = 1
	d._hinge.collision_mask = 0
	d._hinge.position = Vector3(-w * 0.5, 0, 0)
	d.add_child(d._hinge)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, LEAF_T)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(w * 0.5, h * 0.5 + 0.01, 0)
	d._hinge.add_child(mi)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	knob.mesh = sm
	var km := StandardMaterial3D.new()
	km.albedo_color = CityData.color("BRASS", Color(0.69, 0.55, 0.34))
	km.metallic = 1.0
	km.roughness = 0.35
	knob.material_override = km
	knob.position = Vector3(w - 0.07, 0.98, LEAF_T)
	d._hinge.add_child(knob)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	cs.position = mi.position
	d._hinge.add_child(cs)
	var it := DoorInteractable.new()
	it.display_name = "Door"
	d._hinge.add_child(it)
	return d


func toggle() -> void:
	is_open = not is_open
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_hinge, "rotation:y", OPEN_ANGLE if is_open else 0.0, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
