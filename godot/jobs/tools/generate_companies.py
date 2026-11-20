#!/usr/bin/env python3
"""Builds godot/jobs/data/companies.json from data/buildings.json.

Every business on the map becomes an employer. Some storefronts belong to
local chains; campus, hospital, inn, arena and office buildings belong to
institutions and firms. Deterministic (seed 1795).

    python3 godot/jobs/tools/generate_companies.py
"""
import json, os, random, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
B = json.load(open(os.path.join(ROOT, "data", "buildings.json")))["buildings"]
rng = random.Random(1795)

FIRST = ["Avery", "Jordan", "Morgan", "Riley", "Casey", "Taylor", "Quinn", "Drew", "Harper", "Rowan", "Elliot", "Sasha",
         "Dana", "Marisol", "Theo", "Imani", "Priya", "Mateo", "Ines", "Wen", "Kofi", "Hollis", "June", "Bea", "Calvin",
         "Odette", "Reggie", "Lorna", "Tobias", "Nadia", "Emeka", "Greer", "Silas", "Mae", "Dex", "Ruth", "Hank", "Lupe"]
LAST = ["Collins", "Pike", "Ellis", "Chen", "Moreau", "Brooks", "Alvarez", "Hartley", "Okafor", "Lindqvist", "Brandt",
        "Nakamura", "Ferreira", "Doyle", "Santos", "Whitaker", "Ivanova", "Haddad", "Mensah", "Kowalski", "Sato",
        "Ramos", "Pettigrew", "Caldwell", "Hooper", "Mangum", "Battle", "Venable", "Graves", "Tatum", "Lyle", "Barnes"]

# Business type -> (industry, roles hired)
TYPE_ROLES = {
    "cafe": ("Coffee", ["barista"]),
    "bakery": ("Bakery", ["barista", "cashier"]),
    "breakfast": ("Diner", ["barista", "cashier"]),
    "diner": ("Diner", ["barista", "cashier"]),
    "bar": ("Bar", ["bartender"]),
    "brewpub": ("Brewpub", ["bartender", "pizza_cook"]),
    "pizza": ("Pizza", ["pizza_cook", "delivery_rider"]),
    "takeout": ("Takeout", ["delivery_rider", "cashier"]),
    "tacos": ("Tacos", ["delivery_rider", "cashier"]),
    "deli": ("Deli", ["cashier", "delivery_rider"]),
    "clothing": ("Clothing", ["cashier"]),
    "retail": ("Retail", ["cashier"]),
    "gallery": ("Gallery & Print", ["cashier"]),
    "florist": ("Florist", ["cashier", "delivery_rider"]),
    "optics": ("Optician", ["cashier"]),
    "records": ("Records", ["cashier"]),
    "hardware": ("Hardware", ["cashier"]),
    "bookstore": ("Books", ["bookseller", "cashier"]),
    "salon": ("Salon", ["barber"]),
    "tattoo": ("Tattoo", ["tattoo_artist"]),
    "bank": ("Banking", ["bank_teller"]),
    "cinema": ("Cinema", ["cinema_usher"]),
    "dental": ("Dental", ["cashier"]),
    "tutoring": ("Tutoring", ["university_grader"]),
}
# Chains: business type -> (chain name, how many storefronts it owns, tagline)
CHAINS = {
    "cafe": ("Red Clay Roasters", 4, "Small-batch coffee roasted in Carrburg."),
    "takeout": ("Golden Wok Group", 4, "Noodles until 3 AM, six days a week."),
    "clothing": ("Ridgeline Apparel", 3, "Dressing the Mount since 1961."),
    "tacos": ("Summit Taco Co.", 3, "Hand-pressed tortillas, every shift."),
    "pizza": ("Hamilton Street Pizza Group", 3, "Deck-oven pies by the slice."),
    "bar": ("Night Owl Hospitality", 3, "Three bars, one late-night crew."),
    "salon": ("Twin Pines Salons", 3, "Walk-ins welcome at every chair."),
    "deli": ("Copper Saddle Delis", 2, "Sandwiches stacked to code."),
    "bakery": ("Hilltop Bakeries", 2, "Ovens on at 4 AM."),
}
PERKS = ["free_meal", "tip_pool", "staff_discount", "health_plan", "signing_bonus", "flex_shifts", "paid_breaks"]
FOOD_TYPES = {"cafe", "bakery", "breakfast", "diner", "bar", "brewpub", "pizza", "takeout", "tacos", "deli"}

def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

def person():
    return f"{rng.choice(FIRST)} {rng.choice(LAST)}"

def company(cid, name, industry, buildings, roles, **kw):
    food = kw.pop("food", False)
    perks = rng.sample([p for p in PERKS if food or p not in ("free_meal", "tip_pool")], rng.randint(1, 3))
    if food and "free_meal" not in perks and rng.random() < 0.5:
        perks.append("free_meal")
    c = {
        "id": cid, "name": name, "industry": industry, "buildings": buildings, "roles": roles,
        "founded": rng.randint(1890, 2023), "manager": person(), "owner": person(),
        "employees": rng.randint(4, 30), "pay_scale": round(rng.uniform(0.94, 1.12), 2),
        "standards": round(rng.choice([0.0, 0.0, 0.05, 0.1]), 2), "experience_required": 0,
        "rating": round(rng.uniform(3.1, 4.9), 1), "perks": perks, "tagline": "",
    }
    exp = rng.choice([8, 16])
    c.update(kw)
    if "experience_required" not in kw and c["pay_scale"] >= 1.08 and c["standards"] > 0:
        c["experience_required"] = exp
    return c

out = []
used = set()
by_type = {}
for b in B:
    bz = b.get("business")
    if isinstance(bz, dict) and bz.get("type") in TYPE_ROLES:
        by_type.setdefault(bz["type"], []).append(b)

# Chains first.
for t, (cname, n, tag) in CHAINS.items():
    pool = by_type.get(t, [])
    if len(pool) < n + 2:
        continue
    picks = rng.sample(pool, n)
    ind, roles = TYPE_ROLES[t]
    for p in picks:
        used.add(p["id"])
    out.append(company(slug(cname), cname, ind, [p["id"] for p in picks], roles, food=t in FOOD_TYPES,
                       chain=True, branch_names={p["id"]: p["business"]["name"] for p in picks},
                       tagline=tag, pay_scale=round(rng.uniform(0.94, 1.02), 2), employees=rng.randint(30, 90),
                       perks=sorted(set(["flex_shifts", "staff_discount"] + (["free_meal"] if t in FOOD_TYPES else [])))))

# Independent storefronts.
for t, pool in sorted(by_type.items()):
    ind, roles = TYPE_ROLES[t]
    for b in pool:
        if b["id"] in used:
            continue
        name = b["business"]["name"]
        out.append(company(slug(name) + "_" + b["id"].lower(), name, ind, [b["id"]], roles, food=t in FOOD_TYPES,
                           tagline=f"Independent {ind.lower()} on {'Hamilton St' if b['district'] == 'hamilton_strip' else b['district'].replace('_', ' ').title()}."))

ids = {b["id"]: b for b in B}
def have(*xs):
    return [x for x in xs if x in ids]

# Institutions. Each role can be limited to some of the company's buildings with role_buildings.
acad = [b["id"] for b in B if b["typology"] == "historic_academic" and (b["id"].startswith("ONSU_") or b["id"] in ("LM05_FOUNDERS_HALL", "LM07_MOORHOUSE"))]
libs = have("LM03_WILBERFORCE", "LM08_ASHGROVE", "LM04_DAVIES_STACKS")
labs = [b["id"] for b in B if b["id"].startswith("ONSU_") and b["typology"] == "office_lab"]
halls = have("LM09_STUDENT_UNION", "LM09_DINING_HALL", "LM06_ELDER_WEST", "LM06_ELDER_EAST", "ONSU_0023", "ONSU_0024", "ONSU_0025", "ONSU_0027")
out.append(company("onsu", "Old North State University", "University", acad + libs + labs + halls,
                   ["university_grader", "librarian", "custodian", "it_support"],
                   role_buildings={"university_grader": acad, "librarian": have("LM03_WILBERFORCE", "LM08_ASHGROVE"),
                                   "custodian": halls, "it_support": have("LM04_DAVIES_STACKS") + labs},
                   tagline="Lux et Libertas, est. 1795.", founded=1795, employees=3800, pay_scale=1.0, standards=0.05,
                   perks=["health_plan", "paid_breaks", "staff_discount"], rating=4.2))
out.append(company("onsu_health", "ONSU Health", "Hospital", have("LM13_MED_TOWER_A", "LM13_MED_TOWER_B", "LM13_MED_TOWER_C", "LM13_MED_TOWER_D"),
                   ["er_nurse", "lab_tech", "custodian"],
                   role_buildings={"er_nurse": have("LM13_MED_TOWER_D"), "lab_tech": have("LM13_MED_TOWER_A"),
                                   "custodian": have("LM13_MED_TOWER_B", "LM13_MED_TOWER_C")},
                   tagline="Level I trauma center for the Piedmont.", founded=1952, employees=6100, pay_scale=1.05,
                   standards=0.05, perks=["health_plan", "free_meal", "signing_bonus"], rating=4.0))
out.append(company("onsu_athletics", "ONSU Athletics", "Sports & Events", have("LM10_BENEFACTOR_STADIUM", "LM11_COACHS_DOME"),
                   ["cashier", "custodian"], tagline="Go Pitch Soles.", founded=1888, employees=420, pay_scale=0.98,
                   perks=["staff_discount", "flex_shifts"], industry_catalog="Concessions", rating=4.4))
out.append(company("pamlico_inn", "Pamlico Inn & Tavern", "Hotel", have("LM12_PAMLICO_INN"),
                   ["inn_front_desk", "bartender", "custodian"], tagline="Rooms, rocking chairs and a ballroom since 1924.",
                   founded=1924, employees=85, pay_scale=1.04, perks=["free_meal", "tip_pool", "health_plan"], rating=4.6, food=True))
out.append(company("loomhouse_coop", "Loomhouse Co-op Market", "Grocery", have("CBG_1178"), ["cashier", "custodian"],
                   tagline="Member-owned groceries in the old textile mill.", founded=1979, employees=60, pay_scale=1.06,
                   perks=["staff_discount", "health_plan"], industry_catalog="Grocery", rating=4.7))
twr = [b["id"] for b in B if b["id"].endswith("_TWR")]
firms = [("Piedmont Analytics", ["it_support", "custodian"], "Data for every county in Pamlico."),
         ("Tarheel Ledger Partners", ["it_support", "custodian"], "Accounting and payroll for Hamilton Street.")]
for i, b in enumerate(twr[:len(firms)]):
    n, r, tag = firms[i]
    out.append(company(slug(n), n, "Office", [b], r, tagline=tag, pay_scale=round(rng.uniform(1.05, 1.15), 2),
                       employees=rng.randint(40, 160), perks=["health_plan", "flex_shifts"], experience_required=0))
out.append(company("mount_parking", "Cathedral Mount Parking Authority", "Parking", have("RRD_0029", "RRD_0030", "LM13_MED_DECK_1"),
                   ["cashier", "custodian"], tagline="Pay at the booth.", founded=1971, employees=35, pay_scale=0.97,
                   perks=["health_plan"], industry_catalog="Parking", rating=3.2))

seen = {}
for c in out:
    c.pop("food", None)
    if c["name"] in seen:
        b = ids[c["buildings"][0]]
        street = {"hamilton_strip": "Hamilton St", "rosemary_row": "Rosemary St", "carrburg": "Carrburg"}.get(b["district"], b["district"].replace("_", " ").title())
        base = c["name"]
        c["name"] = f"{base} ({street})"
        n = 2
        while c["name"] in seen:
            c["name"] = f"{base} ({street} {n})"
            n += 1
    seen[c["name"]] = True
json.dump({"version": 1, "seed": 1795, "count": len(out), "companies": out},
          open(os.path.join(ROOT, "godot", "jobs", "data", "companies.json"), "w"), indent=1, ensure_ascii=False)
postings = sum(len(c["roles"]) for c in out)
print(f"{len(out)} companies, {postings} postings, {sum(1 for c in out if c.get('chain'))} chains")
