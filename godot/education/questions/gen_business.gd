extends RefCounted
## Business and economics question generator.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"equilibrium": "Supply and demand", "elasticity": "Elasticity", "interest": "Interest",
	"profit": "Revenue and profit", "break_even": "Break-even analysis", "markup": "Markup and margin",
	"accounting_eq": "The accounting equation", "accounts": "Account types", "journal": "Journal entries",
	"gdp": "GDP", "inflation": "Inflation", "unemployment": "Unemployment", "concepts": "Economic concepts",
	"marketing": "Marketing", "management": "Management", "depreciation": "Depreciation",
	"ratios": "Financial ratios", "present_value": "Time value of money", "coffee": "Coffee service",
	"food_safety": "Food safety",
}

const ACCOUNTS := [
	["Cash", "Asset"], ["Accounts receivable", "Asset"], ["Inventory", "Asset"], ["Equipment", "Asset"], ["Prepaid rent", "Asset"],
	["Accounts payable", "Liability"], ["Wages payable", "Liability"], ["Bank loan", "Liability"], ["Unearned revenue", "Liability"],
	["Owner's capital", "Equity"], ["Retained earnings", "Equity"], ["Sales revenue", "Revenue"], ["Service fees earned", "Revenue"],
	["Rent expense", "Expense"], ["Utilities expense", "Expense"], ["Wages expense", "Expense"], ["Depreciation expense", "Expense"],
]
const JOURNAL := [
	["Paid $500 rent in cash", "Debit Rent expense, credit Cash"], ["Bought supplies on credit", "Debit Supplies, credit Accounts payable"],
	["Owner invested cash", "Debit Cash, credit Owner's capital"], ["Billed a client for services", "Debit Accounts receivable, credit Service revenue"],
	["Collected cash from a client's account", "Debit Cash, credit Accounts receivable"], ["Paid a supplier what we owed", "Debit Accounts payable, credit Cash"],
	["Took out a bank loan", "Debit Cash, credit Notes payable"], ["Paid employee wages", "Debit Wages expense, credit Cash"],
	["Recorded a month of depreciation", "Debit Depreciation expense, credit Accumulated depreciation"],
]
const CONCEPTS := [
	["Value of the next best alternative given up", "Opportunity cost"], ["Each extra unit adds less satisfaction", "Diminishing marginal utility"],
	["Market with one seller", "Monopoly"], ["Market with a few large sellers", "Oligopoly"], ["Many sellers of identical goods", "Perfect competition"],
	["A cost already paid that cannot be recovered", "Sunk cost"], ["Effect on a third party not in the deal", "Externality"],
	["Central bank raising rates is", "Contractionary monetary policy"], ["Government spending more to boost demand", "Expansionary fiscal policy"],
	["Two straight quarters of falling real GDP (rule of thumb)", "Recession"], ["Price ceiling below equilibrium causes a", "Shortage"],
	["Price floor above equilibrium causes a", "Surplus"], ["Goods bought more as income rises", "Normal goods"],
	["Goods bought less as income rises", "Inferior goods"], ["Specializing where your opportunity cost is lowest", "Comparative advantage"],
]
const MARKETING := [
	["The four Ps", "Product, price, place, promotion"], ["Dividing a market into groups", "Segmentation"],
	["Choosing which segment to serve", "Targeting"], ["How a brand wants to be seen versus rivals", "Positioning"],
	["Pricing low to win share fast", "Penetration pricing"], ["Pricing high at launch, lowering later", "Price skimming"],
	["Cost to win one new customer", "Customer acquisition cost"], ["Share of visitors who buy", "Conversion rate"],
	["Strengths, weaknesses, opportunities, threats", "SWOT analysis"], ["Total profit expected from one customer", "Customer lifetime value"],
]
const MANAGEMENT := [
	["Setting goals and deciding how to reach them", "Planning"], ["Arranging people and resources", "Organizing"],
	["Motivating and directing people", "Leading"], ["Measuring results against goals", "Controlling"],
	["Hierarchy of needs", "Maslow"], ["Goals that are specific, measurable, achievable, relevant, time-bound", "SMART goals"],
	["Number of people reporting to one manager", "Span of control"], ["Decisions made at the top", "Centralization"],
	["Moving work to an outside company", "Outsourcing"], ["Employees share in decisions", "Participative leadership"],
]
const COFFEE := [
	["Standard espresso brew ratio (coffee : liquid out)", "About 1 : 2"], ["Typical single espresso shot time", "25–30 seconds"],
	["Ideal brewing water temperature", "90–96 °C (195–205 °F)"], ["Espresso with steamed milk and thin foam", "Latte"],
	["Espresso with equal parts milk and thick foam", "Cappuccino"], ["Espresso topped with hot water", "Americano"],
	["Shot runs too fast and tastes sour", "Grind finer"], ["Shot runs too slow and tastes bitter", "Grind coarser"],
	["Steamed milk target temperature", "55–65 °C (130–150 °F)"], ["Compressing grounds in the basket", "Tamping"],
]
const FOOD := [
	["Cold holding temperature", "41 °F (5 °C) or below"], ["Hot holding temperature", "135 °F (57 °C) or above"],
	["Cook poultry to", "165 °F (74 °C)"], ["Cook ground beef to", "155 °F (68 °C)"], ["Cook whole fish and steaks to", "145 °F (63 °C)"],
	["The temperature danger zone", "41–135 °F (5–57 °C)"], ["How long to wash hands", "At least 20 seconds"],
	["Safest way to thaw meat", "In the refrigerator"], ["Store raw chicken where in the fridge", "On the bottom shelf"],
	["First in, first out means", "Use older stock first"], ["Cutting board after raw meat", "Wash, rinse, sanitize"],
	["Reheat leftovers for hot holding to", "165 °F (74 °C)"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	match topic:
		"equilibrium":
			var b := rng.randi_range(1, 5); var d := rng.randi_range(1, 5); var p := rng.randi_range(2, 20)
			var c := rng.randi_range(0, 20); var a := c + (b + d) * p
			return MC.build(rng, "Demand Qd = %d − %dP, supply Qs = %d + %dP. Equilibrium price?" % [a, b, c, d], p,
				[a - b * p, p + 1, p - 1, a / maxi(b, 1)], "Set Qd = Qs.")
		"elasticity":
			var dq := rng.randi_range(1, 12) * 5; var dp := rng.randi_range(1, 6) * 5
			var e := float(dq) / dp
			var r := "Elastic" if e > 1.0 else ("Unit elastic" if is_equal_approx(e, 1.0) else "Inelastic")
			if rng.randf() < 0.5:
				return MC.build(rng, "Price rises %d%% and quantity demanded falls %d%%. Demand is:" % [dp, dq], r, ["Elastic", "Inelastic", "Unit elastic", "Perfectly inelastic"], "|%ΔQ / %ΔP| = " + MC._fmt(snappedf(e, 0.01)))
			return MC.build(rng, "Price rises %d%%, quantity falls %d%%. Price elasticity (absolute)?" % [dp, dq], snappedf(e, 0.01), MC.near_floats(rng, e, 2))
		"interest":
			var pr := rng.randi_range(1, 20) * 500; var r := rng.randi_range(2, 10); var t := rng.randi_range(1, 5)
			if rng.randf() < 0.5:
				var si := pr * r * t / 100.0
				return MC.build(rng, "Simple interest on $%d at %d%% for %d years?" % [pr, r, t], MC.money(si), [MC.money(si * 1.1), MC.money(pr * r / 100.0), MC.money(si + pr), MC.money(si / 2)], "I = P·r·t.")
			var amt := pr * pow(1.0 + r / 100.0, t)
			return MC.build(rng, "$%d compounded yearly at %d%% for %d years grows to?" % [pr, r, t], MC.money(amt), [MC.money(pr * (1 + r * t / 100.0)), MC.money(amt * 1.05), MC.money(amt - pr), MC.money(pr * pow(1.0 + r / 100.0, t + 1))], "A = P(1 + r)ᵗ.")
		"profit":
			var price := rng.randi_range(5, 60); var units := rng.randi_range(10, 400); var fixed := rng.randi_range(1, 30) * 100; var vc := rng.randi_range(1, price - 1)
			var pi := price * units - fixed - vc * units
			return MC.build(rng, "Price $%d, %d units, fixed costs $%d, variable cost $%d per unit. Profit?" % [price, units, fixed, vc], MC.money_int(pi),
				[MC.money_int(price * units - fixed), MC.money_int(price * units), MC.money_int(pi + fixed), MC.money_int(price * units - vc * units - fixed * 2)])
		"break_even":
			var vc := rng.randi_range(2, 30); var cm := rng.randi_range(2, 20); var units := rng.randi_range(5, 200)
			var fixed := cm * units
			return MC.build(rng, "Fixed costs $%d, price $%d, variable cost $%d. Break-even units?" % [fixed, vc + cm, vc], units,
				[fixed / (vc + cm), units + 1, fixed / maxi(vc, 1), units * 2], "Fixed ÷ (price − variable cost).")
		"markup":
			var cost := rng.randi_range(2, 40) * 5; var mu: int = MC.pick(rng, [20, 25, 40, 50, 60, 100])
			var price := cost * (1 + mu / 100.0)
			if rng.randf() < 0.5:
				return MC.build(rng, "Cost $%d with %d%% markup on cost. Selling price?" % [cost, mu], MC.money(price), [MC.money(cost * mu / 100.0), MC.money(price * 1.1), MC.money(cost + mu), MC.money(cost / (1 - mu / 200.0))])
			var margin := (price - cost) / price * 100.0
			return MC.build(rng, "Cost $%d, price $%s. Gross margin (%% of price)?" % [cost, MC._fmt(price)], MC._fmt(snappedf(margin, 0.1)) + "%", [str(mu) + "%", MC._fmt(snappedf(100 - margin, 0.1)) + "%", MC._fmt(snappedf(margin / 2, 0.1)) + "%", MC._fmt(snappedf(margin + 10, 0.1)) + "%"])
		"accounting_eq":
			var a := rng.randi_range(10, 99) * 1000; var l := rng.randi_range(1, a / 1000 - 1) * 1000
			var e := a - l
			var which := rng.randi_range(0, 2)
			if which == 0:
				return MC.build(rng, "Liabilities $%d, equity $%d. Total assets?" % [l, e], MC.money_int(a), [MC.money_int(e - l), MC.money_int(l), MC.money_int(a + l), MC.money_int(e)])
			if which == 1:
				return MC.build(rng, "Assets $%d, equity $%d. Liabilities?" % [a, e], MC.money_int(l), [MC.money_int(a + e), MC.money_int(e), MC.money_int(l + 1000), MC.money_int(a)])
			return MC.build(rng, "Assets $%d, liabilities $%d. Equity?" % [a, l], MC.money_int(e), [MC.money_int(a + l), MC.money_int(l), MC.money_int(e - 1000), MC.money_int(a)], "Assets = Liabilities + Equity.")
		"accounts":
			return _account(rng)
		"journal":
			return MC.from_bank(rng, JOURNAL, "Journal entry: %s?", 0, 1)
		"gdp":
			var c := rng.randi_range(5, 20) * 100; var i := rng.randi_range(1, 6) * 100; var g := rng.randi_range(2, 8) * 100; var x := rng.randi_range(1, 5) * 100; var m := rng.randi_range(1, 6) * 100
			var gdp := c + i + g + x - m
			return MC.build(rng, "C = %d, I = %d, G = %d, exports %d, imports %d. GDP?" % [c, i, g, x, m], gdp, [c + i + g + x + m, c + i + g, gdp + m, gdp - x], "GDP = C + I + G + (X − M).")
		"inflation":
			var c1 := rng.randi_range(100, 250); var pct := rng.randi_range(1, 12)
			var c2 := snappedf(c1 * (1 + pct / 100.0), 0.1)
			return MC.build(rng, "CPI goes from %d to %s. Inflation rate?" % [c1, MC._fmt(c2)], str(pct) + "%", [str(pct + 1) + "%", MC._fmt(snappedf(c2 - c1, 0.1)) + "%", str(maxi(pct - 1, 0)) + "%", str(pct * 2) + "%"], "(new − old) ÷ old.")
		"unemployment":
			var lf := rng.randi_range(10, 200) * 100; var pct := rng.randi_range(2, 15)
			var un := lf * pct / 100
			return MC.build(rng, "Labor force %d, unemployed %d. Unemployment rate?" % [lf, un], str(pct) + "%", [str(pct + 2) + "%", str(maxi(pct - 1, 1)) + "%", str(100 - pct) + "%", MC._fmt(snappedf(un * 100.0 / (lf + un), 0.1)) + "%"], "Unemployed ÷ labor force.")
		"concepts":
			return MC.both_ways(rng, CONCEPTS, "Which concept: %s?", "Which describes \"%s\"?")
		"marketing":
			return MC.both_ways(rng, MARKETING, "Which marketing term: %s?", "Which describes \"%s\"?")
		"management":
			return MC.from_bank(rng, MANAGEMENT, "Which management term: %s?", 0, 1)
		"depreciation":
			var cost := rng.randi_range(5, 60) * 1000; var salvage := rng.randi_range(0, 4) * 1000; var life := rng.randi_range(3, 10)
			var dep := (cost - salvage) / float(life)
			return MC.build(rng, "Straight-line: cost $%d, salvage $%d, life %d years. Yearly depreciation?" % [cost, salvage, life], MC.money(dep),
				[MC.money(cost / float(life)), MC.money(dep * 2), MC.money((cost + salvage) / float(life)), MC.money(dep / 2)], "(Cost − salvage) ÷ life.")
		"ratios":
			var cl := rng.randi_range(2, 20) * 1000; var ratio := snappedf(rng.randi_range(5, 30) * 0.1, 0.1)
			var ca := int(cl * ratio)
			return MC.build(rng, "Current assets $%d, current liabilities $%d. Current ratio?" % [ca, cl], snappedf(ratio, 0.01), MC.near_floats(rng, ratio, 2), "Current assets ÷ current liabilities.")
		"present_value":
			var fv := rng.randi_range(1, 20) * 1000; var r := rng.randi_range(2, 10); var t := rng.randi_range(1, 5)
			var pv := fv / pow(1.0 + r / 100.0, t)
			return MC.build(rng, "Present value of $%d received in %d years at %d%%?" % [fv, t, r], MC.money(pv),
				[MC.money(fv * pow(1.0 + r / 100.0, t)), MC.money(fv * (1 - r * t / 100.0)), MC.money(pv * 1.1), MC.money_int(fv)], "PV = FV ÷ (1 + r)ᵗ.")
		"coffee":
			return MC.from_bank(rng, COFFEE, "Barista: %s?", 0, 1)
		"food_safety":
			return MC.from_bank(rng, FOOD, "Food safety: %s?", 0, 1)
	return MC.build(rng, "What does a business earn from sales?", "Revenue", ["Expense", "Liability", "Equity"])

func _account(rng: RandomNumberGenerator) -> Dictionary:
	var row: Array = MC.pick(rng, ACCOUNTS)
	return MC.build(rng, "What type of account is \"%s\"?" % row[0], row[1], ["Asset", "Liability", "Equity", "Revenue", "Expense"])
