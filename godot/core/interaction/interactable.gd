class_name Interactable
extends Node3D
## Base class for anything the player can use: furniture, doors, NPCs, job terminals.
##
## Put it as a CHILD of a CollisionObject3D (StaticBody3D, Area3D, CharacterBody3D...).
## The player's look ray (2.5 m) hits the body; Interactable.find_from(collider) walks up
## and down from it to find this node. See docs/INTERFACES.md.
##
## Subclasses override get_actions() and perform(). The simple path: set default_action_id /
## default_action_label in the inspector and connect to `performed`.

signal performed(action_id: String, actor: Node)

@export var display_name: String = "Object"
@export var enabled: bool = true
@export var default_action_id: String = "use"
@export var default_action_label: String = "Use"
## Game minutes the default action takes (0 = instant).
@export var default_action_minutes: float = 0.0


## Every action available right now. Each entry:
## { "id": String, "label": String, "minutes": float (optional), "enabled": bool (optional) }
func get_actions(_actor: Node) -> Array[Dictionary]:
	return [{"id": default_action_id, "label": default_action_label, "minutes": default_action_minutes}]


## Run one action. Subclasses call super.perform(action_id, actor) or emit_performed() at the end.
func perform(action_id: String, actor: Node) -> void:
	emit_performed(action_id, actor)


## Shown in the HUD prompt, e.g. "[E] Sit — Armchair".
func get_prompt(actor: Node) -> String:
	var acts := get_actions(actor)
	if acts.is_empty():
		return display_name
	var extra := "" if acts.size() < 2 else "   [Hold E] More (%d)" % acts.size()
	return "[E] %s  -  %s%s" % [acts[0].get("label", "Use"), display_name, extra]


## Convenience: run the first action.
func interact(actor: Node) -> void:
	var acts := get_actions(actor)
	if not acts.is_empty():
		perform(String(acts[0]["id"]), actor)


func emit_performed(action_id: String, actor: Node) -> void:
	performed.emit(action_id, actor)
	GameState.emit_action(action_id, self, actor)


## Find the Interactable that owns a collider: the collider itself, its children, or its ancestors.
static func find_from(n: Node) -> Interactable:
	if n == null:
		return null
	for c in n.get_children():
		if c is Interactable and c.enabled:
			return c
	var cur := n
	while cur != null:
		if cur is Interactable:
			return cur
		if cur.has_meta("interactable"):
			var m = cur.get_meta("interactable")
			if m is Interactable:
				return m
		cur = cur.get_parent()
	return null
