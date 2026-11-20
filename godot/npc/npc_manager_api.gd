## Small helpers shared by the NPC autoload and the interactable.
class_name NpcManagerApi
extends RefCounted

const FALLBACK_LINES := ["Hey.", "Nice day for it.", "Can't stop, I'm running late.", "Go Heels... I mean, go Mounties.", "Have we met?", "Hi there!"]


## A line of dialogue for this NPC. Uses the Dialogue autoload from the
## dialogue thread when present (it owns the 30 personalities), else a short
## generic line.
static func line_for(body: Node, context: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var dlg := tree.root.get_node_or_null("Dialogue") if tree else null
	if dlg:
		for m in ["line_for", "get_line"]:
			if dlg.has_method(m):
				var r = dlg.call(m, body, context)
				if r is String and r != "":
					return r
	var i: int = body.get("npc_index") if body.get("npc_index") != null else 0
	return FALLBACK_LINES[absi(hash([i, context, Time.get_ticks_msec() / 60000])) % FALLBACK_LINES.size()]
