extends RefCounted
## Cash, bank, hourly pay sessions and recurring bills.

signal money_changed(cash: float, bank: float, delta: float, reason: String)
signal pay_credited(session_id: String, amount: float)
signal paid_session_started(session_id: String, hourly_rate: float)
signal paid_session_ended(session_id: String, total: float, minutes: int)
signal bill_paid(bill_id: String, amount: float)
signal bill_missed(bill_id: String, amount: float)

const LEDGER_MAX := 200

var cash: float = 400.0
var bank: float = 0.0
var debt: float = 0.0
var ledger: Array = []
## session_id -> {rate, mult, tips_rate, reason, to_bank, max_minutes, minutes, accrued, total}
var sessions: Dictionary = {}
## bill_id -> {amount, every_days, reason, next_day}
var bills: Dictionary = {}

var _now: Callable = func() -> float: return 0.0


func _init(now_minutes: Callable = Callable()) -> void:
	if now_minutes.is_valid():
		_now = now_minutes


func _to_string() -> String:
	return "$%.2f" % cash


static func fmt(amount: float) -> String:
	var sign := "-" if amount < 0.0 else ""
	return "%s$%.2f" % [sign, absf(amount)]


func total() -> float:
	return cash + bank


func _log(delta: float, reason: String) -> void:
	ledger.append({"t": _now.call(), "delta": snappedf(delta, 0.01), "reason": reason})
	if ledger.size() > LEDGER_MAX:
		ledger.pop_front()
	money_changed.emit(cash, bank, delta, reason)


## Add money to cash (or the bank). Negative amounts are refused; use spend.
func add(amount: float, reason: String = "", to_bank: bool = false) -> void:
	if amount <= 0.0:
		return
	amount = snappedf(amount, 0.01)
	if to_bank:
		bank += amount
	else:
		cash += amount
	_log(amount, reason)


func can_afford(amount: float, allow_bank: bool = true) -> bool:
	return (cash + (bank if allow_bank else 0.0)) + 0.0001 >= amount


## Pay from cash first, then the bank (card). Returns false and changes
## nothing if there is not enough.
func spend(amount: float, reason: String = "", allow_bank: bool = true) -> bool:
	if amount <= 0.0:
		return true
	amount = snappedf(amount, 0.01)
	if not can_afford(amount, allow_bank):
		return false
	var from_cash: float = min(cash, amount)
	cash -= from_cash
	bank -= amount - from_cash
	cash = snappedf(cash, 0.01)
	bank = snappedf(bank, 0.01)
	_log(-amount, reason)
	return true


## Remove cash without a choice (mugging, police seizure). Returns the amount taken.
func lose_cash(amount: float, reason: String = "") -> float:
	var taken: float = snappedf(min(cash, max(amount, 0.0)), 0.01)
	if taken > 0.0:
		cash -= taken
		_log(-taken, reason)
	return taken


func deposit(amount: float) -> bool:
	amount = snappedf(min(amount, cash), 0.01)
	if amount <= 0.0:
		return false
	cash -= amount
	bank += amount
	_log(0.0, "Deposit %s" % fmt(amount))
	return true


func withdraw(amount: float) -> bool:
	amount = snappedf(min(amount, bank), 0.01)
	if amount <= 0.0:
		return false
	bank -= amount
	cash += amount
	_log(0.0, "Withdraw %s" % fmt(amount))
	return true


func borrow(amount: float, reason: String = "Loan") -> void:
	debt += amount
	add(amount, reason, true)


func repay(amount: float) -> float:
	var pay: float = min(amount, debt)
	if pay <= 0.0 or not spend(pay, "Debt payment"):
		return 0.0
	debt = snappedf(debt - pay, 0.01)
	return pay


# --- Hourly pay ---------------------------------------------------------------

## Start paying `hourly_rate` per in-game hour. Options: reason, to_bank,
## max_minutes (auto-end), tips_rate (extra per hour, not scaled), mult.
func start_paid_session(session_id: String, hourly_rate: float, opts: Dictionary = {}) -> void:
	if sessions.has(session_id):
		end_paid_session(session_id)
	sessions[session_id] = {
		"rate": hourly_rate,
		"mult": float(opts.get("mult", 1.0)),
		"tips_rate": float(opts.get("tips_rate", 0.0)),
		"reason": str(opts.get("reason", session_id)),
		"to_bank": bool(opts.get("to_bank", false)),
		"max_minutes": int(opts.get("max_minutes", 0)),
		"minutes": 0,
		"accrued": 0.0,
		"total": 0.0,
	}
	paid_session_started.emit(session_id, hourly_rate)


func has_session(session_id: String) -> bool:
	return sessions.has(session_id)


func set_session_multiplier(session_id: String, mult: float) -> void:
	if sessions.has(session_id):
		sessions[session_id].mult = max(mult, 0.0)


func set_session_rate(session_id: String, hourly_rate: float) -> void:
	if sessions.has(session_id):
		sessions[session_id].rate = hourly_rate


func session_info(session_id: String) -> Dictionary:
	return sessions.get(session_id, {}).duplicate()


## Credit the accrued (uncredited) pay of a session now.
func _credit(session_id: String) -> float:
	var s: Dictionary = sessions[session_id]
	var amount: float = floorf(s.accrued * 100.0) / 100.0
	if amount <= 0.0:
		return 0.0
	s.accrued -= amount
	s.total += amount
	add(amount, s.reason, s.to_bank)
	pay_credited.emit(session_id, amount)
	return amount


## Ends the session, credits what is left (pro rata) and returns its total pay.
func end_paid_session(session_id: String) -> float:
	if not sessions.has(session_id):
		return 0.0
	var s: Dictionary = sessions[session_id]
	s.accrued = ceilf(s.accrued * 100.0 - 0.0001) / 100.0
	_credit(session_id)
	var t: float = snappedf(s.total, 0.01)
	var mins: int = s.minutes
	sessions.erase(session_id)
	paid_session_ended.emit(session_id, t, mins)
	return t


func on_minute() -> void:
	var ending: Array = []
	for id in sessions:
		var s: Dictionary = sessions[id]
		s.minutes += 1
		s.accrued += (s.rate * s.mult + s.tips_rate) / 60.0
		if s.max_minutes > 0 and s.minutes >= s.max_minutes:
			ending.append(id)
	for id in ending:
		end_paid_session(id)


func on_hour() -> void:
	for id in sessions.keys():
		_credit(id)


# --- Bills --------------------------------------------------------------------

func add_bill(bill_id: String, amount: float, every_days: int, reason: String = "", first_day: int = -1) -> void:
	var today := int(_now.call()) / 1440 + 1
	bills[bill_id] = {
		"amount": amount, "every_days": max(every_days, 1), "reason": reason if reason != "" else bill_id,
		"next_day": first_day if first_day > 0 else today + max(every_days, 1),
	}


func remove_bill(bill_id: String) -> void:
	bills.erase(bill_id)


func on_day(day: int) -> void:
	for id in bills.keys():
		var b: Dictionary = bills[id]
		if day < int(b.next_day):
			continue
		b.next_day = day + int(b.every_days)
		if spend(b.amount, b.reason):
			bill_paid.emit(id, b.amount)
		else:
			debt += b.amount
			bill_missed.emit(id, b.amount)


func to_save() -> Dictionary:
	return {"cash": cash, "bank": bank, "debt": debt, "ledger": ledger.duplicate(true),
		"sessions": sessions.duplicate(true), "bills": bills.duplicate(true)}


func from_save(d: Dictionary) -> void:
	cash = float(d.get("cash", cash))
	bank = float(d.get("bank", bank))
	debt = float(d.get("debt", debt))
	ledger = d.get("ledger", [])
	sessions = d.get("sessions", {})
	bills = d.get("bills", {})
	# JSON turns ints into floats; restore the int fields.
	for id in sessions:
		sessions[id].minutes = int(sessions[id].minutes)
		sessions[id].max_minutes = int(sessions[id].max_minutes)
