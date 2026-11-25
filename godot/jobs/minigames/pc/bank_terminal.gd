extends PCMinigame
## Bluebird Savings teller system: post deposits/cashing, catch bad checks.

const NAMES := ["Avery Collins", "Jordan Pike", "Morgan Ellis", "Riley Chen", "Casey Moreau", "Taylor Brooks", "Quinn Alvarez", "Drew Hartley"]
const ONES := ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
	"thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
const TENS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]


func _app_name() -> String:
	return "%s  ·  TellerLink 4" % company_name("Bluebird Savings")


func words(n: int) -> String:
	var out := ""
	if n >= 1000:
		out += words(n / 1000) + " thousand "
		n %= 1000
	if n >= 100:
		out += ONES[n / 100] + " hundred "
		n %= 100
	if n >= 20:
		out += TENS[n / 10] + ("-" + ONES[n % 10] if n % 10 else "") + " "
	elif n > 0:
		out += ONES[n] + " "
	return out.strip_edges()


func _make_task() -> Dictionary:
	var name_s: String = pick(NAMES)
	var acct := "%04d%05d" % [rng.randi_range(1000, 9999), rng.randi_range(0, 99999)]
	var balance := float(rng.randi_range(200, 9000))
	var dollars := rng.randi_range(20, 2400 if difficulty > 0.4 else 900)
	var cents := rng.randi_range(0, 99)
	var amount := dollars + cents / 100.0
	var problem := ""
	var roll := rng.randf()
	var shown_words := words(dollars)
	var sig := name_s
	if roll < 0.12 + 0.1 * difficulty:
		problem = "words"
		shown_words = words(dollars + pick([10, 100, 1]))
	elif roll < 0.22 + 0.15 * difficulty:
		problem = "signature"
		sig = name_s.split(" ")[0] + " " + pick(["Smith", "Doe", "Jones"])
	elif roll < 0.3 + 0.15 * difficulty:
		problem = "funds"
		balance = floorf(amount * 0.5)
	var screen := "[b]CHECK #%d[/b]                        Date: Nov %d\n\nPay to the order of: [b]CASH[/b]\nAmount: [b]$%s[/b]\n%s and %02d/100 dollars\n\nMemo: rent\nSigned: [i]%s[/i]\nAccount: [code]%s[/code]" % [
		rng.randi_range(1001, 4999), rng.randi_range(1, 28), money(amount), shown_words.capitalize(), cents, sig, acct]
	var side := "[b]Account card[/b]\nHolder: %s\nAccount: %s\nAvailable: $%s\n\n[b]Approve (A)[/b] only if:\n- words match the amount\n- signature matches the holder\n- funds cover it\nOtherwise [b]Reject (R)[/b]." % [name_s, acct, money(balance)]
	par_seconds = 22.0
	return {"screen": screen, "side": side, "fields": [
		{"label": "Account #", "answer": acct, "kind": "exact"},
		{"label": "Amount $", "answer": amount, "kind": "money"},
		{"label": "Approve A / Reject R", "answer": "R" if problem != "" else "A", "kind": "text"},
	]}
