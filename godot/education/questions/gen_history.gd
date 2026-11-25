extends RefCounted
## History question generator. One event bank, many question shapes (year,
## which came first, which came last, century), filtered by era and region.
## Entries tagged "local" are fictional Cathedral Mount / ONSU history.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"ancient": "The ancient world", "medieval": "The middle ages", "early_modern": "The early modern world",
	"modern": "The 19th and early 20th centuries", "contemporary": "Since 1945", "us_early": "Early America",
	"us_modern": "Modern America", "europe": "European history", "asia": "Asian history",
	"africa_americas": "Africa and the Americas", "science": "History of science", "local": "Cathedral Mount history",
	"people": "People in history", "world": "World events",
}

# [year, event, region]  (negative years are BC)
const EVENTS := [
	[-2560, "The Great Pyramid of Giza is completed (c.)", "africa"], [-1754, "Hammurabi's law code is written (c.)", "asia"],
	[-776, "The first recorded Olympic Games", "europe"], [-753, "Traditional founding of Rome", "europe"],
	[-509, "The Roman Republic is founded", "europe"], [-490, "Battle of Marathon", "europe"],
	[-480, "Battle of Thermopylae", "europe"], [-399, "Socrates is executed in Athens", "europe"],
	[-334, "Alexander the Great invades the Persian Empire", "europe"], [-221, "Qin Shi Huang unifies China", "asia"],
	[-218, "Hannibal crosses the Alps", "europe"], [-44, "Julius Caesar is assassinated", "europe"],
	[-27, "Augustus becomes the first Roman emperor", "europe"], [79, "Mount Vesuvius buries Pompeii", "europe"],
	[220, "The Han dynasty ends", "asia"], [313, "The Edict of Milan tolerates Christianity", "europe"],
	[476, "The Western Roman Empire falls", "europe"], [622, "Muhammad's migration to Medina (the Hijra)", "asia"],
	[732, "Battle of Tours", "europe"], [800, "Charlemagne is crowned emperor", "europe"],
	[1066, "Battle of Hastings", "europe"], [1088, "The University of Bologna is founded", "europe"],
	[1096, "The First Crusade begins", "europe"], [1206, "Genghis Khan unites the Mongols", "asia"],
	[1215, "Magna Carta is sealed", "europe"], [1271, "Marco Polo sets out for China", "asia"],
	[1347, "The Black Death reaches Europe", "europe"], [1368, "The Ming dynasty is founded", "asia"],
	[1440, "Gutenberg develops his printing press (c.)", "science"], [1453, "Constantinople falls to the Ottomans", "europe"],
	[1492, "Columbus reaches the Caribbean", "americas"], [1498, "Vasco da Gama reaches India by sea", "asia"],
	[1517, "Luther posts the Ninety-five Theses", "europe"], [1519, "Magellan's expedition sets sail", "world"],
	[1521, "Tenochtitlan falls to Cortés", "americas"], [1543, "Copernicus publishes his sun-centered model", "science"],
	[1588, "The Spanish Armada is defeated", "europe"], [1603, "The Tokugawa shogunate begins", "asia"],
	[1607, "Jamestown is founded", "us"], [1620, "The Mayflower lands at Plymouth", "us"],
	[1687, "Newton publishes the Principia", "science"], [1688, "England's Glorious Revolution", "europe"],
	[1707, "The Acts of Union create Great Britain", "europe"], [1752, "Franklin's kite experiment", "science"],
	[1763, "The Treaty of Paris ends the Seven Years' War", "world"], [1765, "Parliament passes the Stamp Act", "us"],
	[1773, "The Boston Tea Party", "us"], [1776, "The Declaration of Independence is adopted", "us"],
	[1781, "British surrender at Yorktown", "us"], [1787, "The US Constitution is signed", "us"],
	[1789, "The storming of the Bastille", "europe"], [1791, "The Bill of Rights is ratified", "us"],
	[1803, "The Louisiana Purchase", "us"], [1804, "Haiti declares independence", "americas"],
	[1805, "Battle of Trafalgar", "europe"], [1812, "The War of 1812 begins", "us"],
	[1815, "Battle of Waterloo", "europe"], [1825, "The Erie Canal opens", "us"],
	[1830, "The Indian Removal Act", "us"], [1848, "The Seneca Falls Convention", "us"],
	[1859, "Darwin publishes On the Origin of Species", "science"], [1861, "The US Civil War begins", "us"],
	[1863, "The Emancipation Proclamation", "us"], [1865, "The 13th Amendment abolishes slavery", "us"],
	[1868, "Japan's Meiji Restoration", "asia"], [1869, "The transcontinental railroad is completed", "us"],
	[1876, "Bell patents the telephone", "science"], [1879, "Edison demonstrates a long-lasting light bulb", "science"],
	[1885, "The Berlin Conference ends", "africa"], [1898, "The Spanish-American War", "us"],
	[1903, "The Wright brothers' first powered flight", "science"], [1905, "Einstein publishes special relativity", "science"],
	[1912, "The Titanic sinks", "world"], [1914, "World War I begins", "world"],
	[1917, "The Russian Revolution", "europe"], [1918, "World War I ends", "world"],
	[1920, "The 19th Amendment gives women the vote", "us"], [1928, "Fleming discovers penicillin", "science"],
	[1929, "The Wall Street crash", "us"], [1933, "The New Deal begins", "us"],
	[1939, "World War II begins", "world"], [1941, "The attack on Pearl Harbor", "us"],
	[1944, "D-Day landings in Normandy", "world"], [1945, "World War II ends", "world"],
	[1947, "India and Pakistan become independent", "asia"], [1948, "The Universal Declaration of Human Rights", "world"],
	[1949, "The People's Republic of China is proclaimed", "asia"], [1950, "The Korean War begins", "asia"],
	[1953, "Watson and Crick describe DNA's double helix", "science"], [1954, "Brown v. Board of Education", "us"],
	[1955, "The Montgomery bus boycott begins", "us"], [1957, "Sputnik 1 is launched", "science"],
	[1960, "Seventeen African countries gain independence", "africa"], [1961, "The Berlin Wall goes up", "europe"],
	[1962, "The Cuban Missile Crisis", "world"], [1963, "The March on Washington", "us"],
	[1964, "The Civil Rights Act", "us"], [1965, "The Voting Rights Act", "us"],
	[1969, "Apollo 11 lands on the Moon", "science"], [1989, "The Berlin Wall falls", "europe"],
	[1990, "The Hubble Space Telescope launches", "science"], [1991, "The Soviet Union dissolves", "europe"],
	[1994, "Nelson Mandela is elected president of South Africa", "africa"], [2001, "The September 11 attacks", "us"],
	[2003, "The Human Genome Project is completed", "science"], [2008, "The global financial crisis", "world"],
	[2020, "COVID-19 is declared a pandemic", "world"],
	# Fictional local history (Cathedral Mount, State of Pamlico)
	[1795, "Old North State University opens its doors", "local"], [1819, "Cathedral Mount is incorporated as a town", "local"],
	[1897, "The Old Cistern gets its copper dome", "local"], [1924, "The Pamlico Inn opens on Cameron Avenue", "local"],
	[1926, "Ghoulgrave Keep is built on Toadstool Hill", "local"], [1927, "Benefactor Memorial Stadium opens", "local"],
	[1929, "Wilberforce Library opens", "local"], [1931, "The Carillon Spire rings for the first time", "local"],
	[1952, "The ONSU Medical Center opens", "local"], [1971, "Davies Stacks is built in the Quarry", "local"],
	[1976, "The Carrburg textile mill becomes a co-op market", "local"], [1986, "The Coach's Dome opens", "local"],
]
const PEOPLE := [
	["Hammurabi", "An early written law code in Babylon"], ["Confucius", "Teachings on ethics and family in ancient China"],
	["Cleopatra VII", "The last active ruler of Ptolemaic Egypt"], ["Julius Caesar", "Crossing the Rubicon"],
	["Charlemagne", "Uniting much of Western Europe around 800"], ["Genghis Khan", "Founding the Mongol Empire"],
	["Mansa Musa", "The wealthy ruler of the Mali Empire"], ["Johannes Gutenberg", "Movable-type printing in Europe"],
	["Martin Luther", "Starting the Protestant Reformation"], ["Galileo Galilei", "Telescope observations backing a sun-centered system"],
	["Isaac Newton", "The laws of motion and universal gravitation"], ["George Washington", "Commanding the Continental Army"],
	["Thomas Jefferson", "Drafting the Declaration of Independence"], ["Napoleon Bonaparte", "Crowning himself Emperor of the French"],
	["Simón Bolívar", "Leading independence movements in South America"], ["Harriet Tubman", "Guiding enslaved people to freedom"],
	["Abraham Lincoln", "Leading the Union in the Civil War"], ["Charles Darwin", "The theory of evolution by natural selection"],
	["Marie Curie", "Pioneering research on radioactivity"], ["Mahatma Gandhi", "Nonviolent resistance for Indian independence"],
	["Franklin D. Roosevelt", "The New Deal"], ["Winston Churchill", "Leading Britain in World War II"],
	["Rosa Parks", "Refusing to give up her bus seat in Montgomery"], ["Martin Luther King Jr.", "The 'I Have a Dream' speech"],
	["Nelson Mandela", "Ending apartheid in South Africa"], ["Neil Armstrong", "First person to walk on the Moon"],
	["Ada Lovelace", "An early published computer program"], ["Albert Einstein", "The theory of relativity"],
	["Florence Nightingale", "Founding modern nursing"], ["Frederick Douglass", "Abolitionist writing and speeches"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	if topic == "people":
		return MC.both_ways(rng, PEOPLE, "What is %s best known for?", "Who is best known for this: %s?")
	var pool := _filter(topic)
	if pool.size() < 4:
		pool = EVENTS.filter(func(e): return e[2] != "local")
	var kind := rng.randi_range(0, 3 if lvl >= 2 else 1)
	var ev: Array = MC.pick(rng, pool)
	match kind:
		0:
			var y: int = ev[0]
			var spread := 2 + lvl * 3
			var wrong := []
			for d in [spread, -spread, spread * 2, -spread * 2, spread * 3, 1, -1]:
				wrong.append(_year(y + d))
			return MC.build(rng, "In what year: %s?" % ev[1], _year(y), MC.shuffle(rng, wrong))
		1, 2:
			var picks := _distinct_years(rng, pool, 4)
			var best: Array = picks[0]
			for p in picks:
				if (kind == 1 and p[0] < best[0]) or (kind == 2 and p[0] > best[0]):
					best = p
			var wrong := picks.filter(func(p): return p != best).map(func(p): return p[1])
			return MC.build(rng, "Which happened %s?" % ("first" if kind == 1 else "most recently"), best[1], wrong,
				"%s (%s)." % [best[1], _year(best[0])])
		_:
			var c := _century(ev[0])
			var wrong := [_century(int(ev[0]) + 100), _century(int(ev[0]) - 100), _century(int(ev[0]) + 200), _century(int(ev[0]) - 200)]
			return MC.build(rng, "In which century: %s?" % ev[1], c, wrong, _year(ev[0]))

func _filter(topic: String) -> Array:
	return EVENTS.filter(func(e):
		var y: int = e[0]
		var r: String = e[2]
		if r == "local":
			return topic == "local"
		match topic:
			"ancient": return y < 500
			"medieval": return y >= 500 and y < 1500
			"early_modern": return y >= 1500 and y < 1800
			"modern": return y >= 1800 and y < 1946
			"contemporary": return y >= 1946
			"us_early": return r == "us" and y < 1866
			"us_modern": return r == "us" and y >= 1866
			"europe": return r == "europe"
			"asia": return r == "asia"
			"africa_americas": return r == "africa" or r == "americas"
			"science": return r == "science"
			"world": return true
		return false)

func _distinct_years(rng: RandomNumberGenerator, pool: Array, n: int) -> Array:
	var out := []
	var years := {}
	for e in MC.shuffle(rng, pool):
		if not years.has(e[0]):
			years[e[0]] = true
			out.append(e)
		if out.size() == n:
			break
	return out

func _year(y: int) -> String:
	return "%d BC" % -y if y < 0 else str(y)

func _century(y: int) -> String:
	var bc := y < 0
	var c := (absi(y) - 1) / 100 + 1 if y != 0 else 1
	var suffix := "th"
	if c % 100 < 11 or c % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(c % 10, "th")
	return "%d%s century%s" % [c, suffix, " BC" if bc else ""]
