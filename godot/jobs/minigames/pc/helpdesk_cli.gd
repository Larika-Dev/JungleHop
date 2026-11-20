extends PCMinigame
## ONSU IT admin console: read the ticket, type the runbook command.

const USERS := ["mlopez", "kchen", "tbaker", "rpatel", "jnguyen", "awright", "slee", "dkim"]
const HOSTS := ["davies-lab-12", "union-kiosk-3", "founders-print", "wilb-cat-02", "med-ws-114"]


func _app_name() -> String:
	return "ONSU IT  ·  admin@davies-stacks:~$"


func _make_task() -> Dictionary:
	var u: String = pick(USERS)
	var h: String = pick(HOSTS)
	var options := [
		["%s is locked out after too many tries." % u, "unlock %s" % u],
		["%s forgot their password." % u, "reset-password %s" % u],
		["Printing is stuck on %s." % h, "restart-service spooler %s" % h],
		["Is %s even online?" % h, "ping %s" % h],
		["New hire %s needs a mailbox." % u, "create-mailbox %s" % u],
		["%s needs the VPN group." % u, "add-group %s vpn" % u],
		["Disk full on %s." % h, "clear-cache %s" % h],
	]
	var count := 1 + (1 if difficulty > 0.5 else 0)
	var fields := []
	var screen := "[b]Ticket queue[/b]\n\n"
	for i in count:
		var o: Array = pick(options)
		screen += "#%d  %s\n" % [rng.randi_range(40000, 49999), o[0]]
		fields.append({"label": "$", "answer": o[1], "kind": "exact_cmd"})
	var side := "[b]Runbook[/b]\n[code]unlock <user>\nreset-password <user>\nrestart-service spooler <host>\nping <host>\ncreate-mailbox <user>\nadd-group <user> vpn\nclear-cache <host>[/code]"
	par_seconds = 12.0 * count
	return {"screen": screen, "side": side, "fields": fields}


func _check_field(f: Dictionary, text: String) -> float:
	if f.kind == "exact_cmd":
		var a := " ".join(text.strip_edges().split(" ", false))
		return 1.0 if a == f.answer else (0.5 if _lev(a, f.answer) == 1 else 0.0)
	return super._check_field(f, text)
