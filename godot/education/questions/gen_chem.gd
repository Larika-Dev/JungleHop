extends RefCounted
## Chemistry question generator.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"elements": "Element symbols", "molar_mass": "Molar mass", "moles": "Moles and mass",
	"ph": "pH", "gas_laws": "Gas laws", "dilution": "Dilution", "stoichiometry": "Stoichiometry",
	"balancing": "Balancing equations", "periodic": "Periodic trends", "bonding": "Chemical bonding",
	"organic": "Organic functional groups", "thermo": "Heat and calorimetry", "atomic": "Atomic structure",
	"titration": "Titration", "lab_safety": "Lab safety",
}

# symbol, name, atomic number, molar mass (g/mol, rounded)
const ELEMENTS := [
	["H", "Hydrogen", 1, 1.008], ["He", "Helium", 2, 4.003], ["Li", "Lithium", 3, 6.94], ["C", "Carbon", 6, 12.011],
	["N", "Nitrogen", 7, 14.007], ["O", "Oxygen", 8, 15.999], ["F", "Fluorine", 9, 18.998], ["Ne", "Neon", 10, 20.180],
	["Na", "Sodium", 11, 22.990], ["Mg", "Magnesium", 12, 24.305], ["Al", "Aluminum", 13, 26.982], ["Si", "Silicon", 14, 28.085],
	["P", "Phosphorus", 15, 30.974], ["S", "Sulfur", 16, 32.06], ["Cl", "Chlorine", 17, 35.45], ["Ar", "Argon", 18, 39.948],
	["K", "Potassium", 19, 39.098], ["Ca", "Calcium", 20, 40.078], ["Fe", "Iron", 26, 55.845], ["Cu", "Copper", 29, 63.546],
	["Zn", "Zinc", 30, 65.38], ["Ag", "Silver", 47, 107.87], ["Sn", "Tin", 50, 118.71], ["I", "Iodine", 53, 126.90],
	["Au", "Gold", 79, 196.97], ["Hg", "Mercury", 80, 200.59], ["Pb", "Lead", 82, 207.2], ["U", "Uranium", 92, 238.03],
	["W", "Tungsten", 74, 183.84], ["Ni", "Nickel", 28, 58.693], ["Co", "Cobalt", 27, 58.933], ["Mn", "Manganese", 25, 54.938],
]
# formula, {symbol: count}
const COMPOUNDS := [
	["H₂O", {"H": 2, "O": 1}], ["CO₂", {"C": 1, "O": 2}], ["NaCl", {"Na": 1, "Cl": 1}], ["CH₄", {"C": 1, "H": 4}],
	["NH₃", {"N": 1, "H": 3}], ["C₆H₁₂O₆", {"C": 6, "H": 12, "O": 6}], ["H₂SO₄", {"H": 2, "S": 1, "O": 4}],
	["CaCO₃", {"Ca": 1, "C": 1, "O": 3}], ["NaOH", {"Na": 1, "O": 1, "H": 1}], ["HCl", {"H": 1, "Cl": 1}],
	["O₂", {"O": 2}], ["KCl", {"K": 1, "Cl": 1}], ["MgO", {"Mg": 1, "O": 1}], ["C₂H₅OH", {"C": 2, "H": 6, "O": 1}],
	["Fe₂O₃", {"Fe": 2, "O": 3}], ["N₂", {"N": 2}],
]
# reaction with blank, correct coefficient
const BALANCE := [
	["_ H₂ + O₂ → 2 H₂O", 2], ["N₂ + _ H₂ → 2 NH₃", 3], ["CH₄ + _ O₂ → CO₂ + 2 H₂O", 2],
	["2 Na + Cl₂ → _ NaCl", 2], ["_ Al + 3 O₂ → 2 Al₂O₃", 4], ["C₃H₈ + _ O₂ → 3 CO₂ + 4 H₂O", 5],
	["2 KClO₃ → 2 KCl + _ O₂", 3], ["_ Fe + 3 O₂ → 2 Fe₂O₃", 4], ["2 H₂O₂ → 2 H₂O + _ O₂", 1],
	["CaCO₃ → CaO + _ CO₂", 1], ["Zn + _ HCl → ZnCl₂ + H₂", 2], ["2 C₂H₆ + _ O₂ → 4 CO₂ + 6 H₂O", 7],
]
const PERIODIC := [
	["Atomic radius going down a group", "Increases"], ["Atomic radius going left to right across a period", "Decreases"],
	["Electronegativity going left to right across a period", "Increases"], ["Ionization energy going down a group", "Decreases"],
	["Most electronegative element", "Fluorine"], ["Group 18 elements are called", "Noble gases"],
	["Group 1 elements are called", "Alkali metals"], ["Group 17 elements are called", "Halogens"],
	["Group 2 elements are called", "Alkaline earth metals"], ["Valence electrons in a Group 16 atom", "6"],
	["Valence electrons in a Group 1 atom", "1"], ["Metallic character going down a group", "Increases"],
]
const BONDING := [
	["Electrons transferred from metal to nonmetal", "Ionic bond"], ["Electrons shared equally", "Nonpolar covalent bond"],
	["Electrons shared unequally", "Polar covalent bond"], ["Sea of delocalized electrons", "Metallic bond"],
	["Weak attraction between H and N, O or F on another molecule", "Hydrogen bond"],
	["Shape of CH₄", "Tetrahedral"], ["Shape of CO₂", "Linear"], ["Shape of H₂O", "Bent"], ["Shape of NH₃", "Trigonal pyramidal"],
	["Shape of BF₃", "Trigonal planar"], ["Bond angle in CH₄", "109.5°"],
]
const ORGANIC := [
	["–OH", "Alcohol"], ["–COOH", "Carboxylic acid"], ["–CHO", "Aldehyde"], ["C=O between two carbons", "Ketone"],
	["–NH₂", "Amine"], ["–COO– between carbons", "Ester"], ["C–O–C", "Ether"], ["C=C double bond", "Alkene"],
	["C≡C triple bond", "Alkyne"], ["–CONH₂", "Amide"], ["Six-carbon aromatic ring", "Benzene ring (arene)"],
]
const SAFETY := [
	["Acid splashed in your eye", "Use the eyewash station for 15 minutes"], ["Diluting concentrated acid", "Add acid to water slowly"],
	["Small fire in a beaker", "Cover it with a watch glass or use the extinguisher"], ["Smelling a chemical", "Waft it toward your nose"],
	["Working with volatile solvents", "Use the fume hood"], ["Broken glassware", "Sweep it into the glass disposal box"],
	["Before leaving the lab", "Wash your hands"], ["Heating a test tube", "Point it away from everyone"],
	["Where to find hazard information", "Safety data sheet (SDS)"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	match topic:
		"elements":
			if rng.randf() < 0.5:
				return MC.both_ways(rng, ELEMENTS, "Which element has the symbol %s?", "What is the symbol for %s?")
			return MC.from_bank(rng, ELEMENTS, "What is the atomic number of %s?", 1, 2)
		"molar_mass":
			var c: Array = MC.pick(rng, COMPOUNDS)
			var m := _mass(c[1])
			return MC.build(rng, "Molar mass of %s (g/mol)?" % c[0], snappedf(m, 0.1), _near(rng, m), "Add up atomic masses.")
		"moles":
			var c: Array = MC.pick(rng, COMPOUNDS)
			var m := snappedf(_mass(c[1]), 0.1)
			var n := rng.randi_range(1, 8) * 0.5
			if rng.randf() < 0.5:
				return MC.build(rng, "Mass of %s mol of %s (M = %s g/mol)?" % [MC._fmt(n), c[0], MC._fmt(m)], snappedf(n * m, 0.1), _near(rng, n * m), "mass = n × M.")
			return MC.build(rng, "%s g of %s (M = %s g/mol) is how many moles?" % [MC._fmt(snappedf(n * m, 0.1)), c[0], MC._fmt(m)], n, [n * 2, n / 2, n + 1, snappedf(m / n, 0.1)], "n = mass / M.")
		"ph":
			var e := rng.randi_range(1, 6)
			if rng.randf() < 0.5:
				return MC.build(rng, "[H⁺] = 1 × 10⁻%d M. What is the pH?" % e, e, [14 - e, -e, e + 1, e - 1 if e > 1 else 7], "pH = −log[H⁺].")
			return MC.build(rng, "[OH⁻] = 1 × 10⁻%d M. What is the pH?" % e, 14 - e, [e, 14 + e, 7, 13 - e], "pOH = %d, pH = 14 − pOH." % e)
		"gas_laws":
			var p1 := rng.randi_range(1, 4); var v1 := rng.randi_range(2, 12) * 2; var p2 := p1 * 2
			if rng.randf() < 0.5:
				return MC.build(rng, "Boyle's law: %d atm, %d L. Pressure doubles to %d atm at constant T. New volume (L)?" % [p1, v1, p2], v1 / 2.0, [v1 * 2, v1, v1 / 4.0, v1 + p1], "P₁V₁ = P₂V₂.")
			var n := rng.randi_range(1, 4)
			var t := 273
			# PV = nRT at 273 K and 1 atm gives 22.4 L/mol
			return MC.build(rng, "Volume of %d mol of ideal gas at 0 °C and 1 atm (L)?" % n, snappedf(22.4 * n, 0.1), [22.4, snappedf(24.5 * n, 0.1), snappedf(11.2 * n, 0.1), n * t], "22.4 L/mol at STP.")
		"dilution":
			var c1 := rng.randi_range(2, 12) * 0.5; var v1 := rng.randi_range(1, 10) * 10.0; var f := rng.randi_range(2, 5)
			var v2 := v1 * f
			return MC.build(rng, "Dilute %s mL of %s M to %s mL. New concentration (M)?" % [MC._fmt(v1), MC._fmt(c1), MC._fmt(v2)], snappedf(c1 / f, 0.01), [c1 * f, c1, snappedf(c1 / (f + 1), 0.01), snappedf(c1 - 1.0 / f, 0.01)], "C₁V₁ = C₂V₂.")
		"stoichiometry":
			var n := rng.randi_range(1, 6)
			var rows := [["2 H₂ + O₂ → 2 H₂O", "H₂", "H₂O", 1.0], ["N₂ + 3 H₂ → 2 NH₃", "N₂", "NH₃", 2.0],
				["CH₄ + 2 O₂ → CO₂ + 2 H₂O", "CH₄", "H₂O", 2.0], ["2 Na + Cl₂ → 2 NaCl", "Cl₂", "NaCl", 2.0],
				["C₃H₈ + 5 O₂ → 3 CO₂ + 4 H₂O", "C₃H₈", "CO₂", 3.0]]
			var r: Array = MC.pick(rng, rows)
			var ans := n * float(r[3])
			return MC.build(rng, "%s\nMoles of %s from %d mol of %s?" % [r[0], r[2], n, r[1]], ans, [n, ans + n, ans * 2, n / float(r[3]), ans + 1, ans - 1, ans * 3, ans + 2], "Use the mole ratio.")
		"balancing":
			var b: Array = MC.pick(rng, BALANCE)
			return MC.build(rng, "Which coefficient balances:  %s" % b[0], b[1], [1, 2, 3, 4, 5, 6, 7].filter(func(v): return v != b[1]))
		"periodic":
			return MC.from_bank(rng, PERIODIC, "%s?", 0, 1)
		"bonding":
			return MC.from_bank(rng, BONDING, "%s?", 0, 1)
		"organic":
			return MC.both_ways(rng, ORGANIC, "Which functional group is %s?", "Which group marks a molecule as a %s?")
		"thermo":
			var m := rng.randi_range(1, 10) * 50; var dt := rng.randi_range(2, 30)
			var q := m * 4.184 * dt
			return MC.build(rng, "Heat (J) to warm %d g of water by %d °C? (c = 4.184 J/g·°C)" % [m, dt], snappedf(q, 1), [snappedf(m * dt, 1), snappedf(q / 1000.0, 0.1), snappedf(q * 2, 1), snappedf(m * 4.184, 1)], "q = m·c·ΔT.")
		"atomic":
			var e: Array = MC.pick(rng, ELEMENTS)
			var a := int(round(float(e[3])))
			var kind := rng.randi_range(0, 2)
			if kind == 0:
				return MC.build(rng, "Protons in a neutral %s atom?" % e[1], e[2], [a, a - int(e[2]), int(e[2]) + 1, int(e[2]) * 2])
			if kind == 1:
				return MC.build(rng, "Neutrons in %s-%d?" % [e[1], a], a - int(e[2]), [e[2], a, a + int(e[2]), a - int(e[2]) + 1])
			return MC.build(rng, "Electrons in a neutral %s atom?" % e[1], e[2], [a, int(e[2]) - 1, int(e[2]) + 1, a - int(e[2])])
		"titration":
			var ca := rng.randi_range(1, 10) * 0.05; var va := rng.randi_range(2, 5) * 5.0; var cb := rng.randi_range(1, 10) * 0.05
			var veq := ca * va / cb
			return MC.build(rng, "%s mL of %s M HCl is titrated with %s M NaOH. Volume at equivalence (mL)?" % [MC._fmt(va), MC._fmt(ca), MC._fmt(cb)],
				snappedf(veq, 0.1), _near(rng, veq), "Moles acid = moles base.")
		"lab_safety":
			return MC.from_bank(rng, SAFETY, "Lab safety: %s?", 0, 1)
	return MC.build(rng, "Chemical symbol for water?", "H₂O", ["HO", "H₂O₂", "OH"])

func _mass(comp: Dictionary) -> float:
	var m := 0.0
	for sym in comp:
		for e in ELEMENTS:
			if e[0] == sym:
				m += float(e[3]) * int(comp[sym])
	return m

func _near(rng: RandomNumberGenerator, x: float) -> Array:
	var out := []
	for f in [1.08, 0.92, 1.5, 0.5, 2.0, 1.2]:
		out.append(snappedf(x * f, 0.1))
	return MC.shuffle(rng, out)
