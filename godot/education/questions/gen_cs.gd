extends RefCounted
## Computer Science question generator: computed questions (number bases,
## logic, code tracing, bit ops) plus concept banks.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"binary": "Binary numbers", "hex": "Hexadecimal", "boolean": "Boolean logic",
	"loops": "Tracing loops", "bitwise": "Bitwise operators", "recursion": "Recursion",
	"arrays": "Arrays and indexing", "big_o": "Algorithm complexity", "data_structures": "Data structures",
	"sorting": "Sorting", "networking": "Networking", "databases": "Databases and SQL",
	"security": "Security", "os": "Operating systems", "hardware": "Computer hardware",
	"software_eng": "Software engineering", "ai": "Machine learning", "it_support": "IT support",
}

const BIG_O := [
	["Binary search on a sorted array", "O(log n)"], ["Linear search", "O(n)"],
	["Merge sort", "O(n log n)"], ["Bubble sort (worst case)", "O(n²)"],
	["Array access by index", "O(1)"], ["Hash table lookup (average)", "O(1)"],
	["Checking every pair in a list", "O(n²)"], ["Generating every subset of n items", "O(2ⁿ)"],
	["Heap sort", "O(n log n)"], ["Inserting at the front of an array", "O(n)"],
	["Push onto a stack", "O(1)"], ["Balanced BST search", "O(log n)"],
	["Generating every ordering of n items", "O(n!)"], ["Summing an array", "O(n)"],
	["Triple nested loop over n", "O(n³)"], ["Quicksort (average)", "O(n log n)"],
]
const STRUCTURES := [
	["Last in, first out", "Stack"], ["First in, first out", "Queue"],
	["Key-value pairs with fast average lookup", "Hash map"], ["Nodes that each point to the next node", "Linked list"],
	["Always gives you the smallest (or largest) item quickly", "Heap / priority queue"],
	["Vertices connected by edges", "Graph"], ["Hierarchy with one root and no cycles", "Tree"],
	["Contiguous block of same-typed items", "Array"], ["Unordered collection with no duplicates", "Set"],
	["Prefix tree for fast word lookup", "Trie"], ["Both ends can push and pop", "Deque"],
]
const NETWORK := [
	["Default port for HTTP", "80"], ["Default port for HTTPS", "443"], ["Default port for SSH", "22"],
	["Default port for DNS", "53"], ["Translates domain names to IP addresses", "DNS"],
	["Hands out IP addresses automatically", "DHCP"], ["Reliable, ordered transport protocol", "TCP"],
	["Connectionless transport protocol", "UDP"], ["Number of bits in an IPv4 address", "32"],
	["Number of bits in an IPv6 address", "128"], ["Address burned into a network card", "MAC address"],
	["Device that forwards packets between networks", "Router"], ["Layer 2 device connecting hosts on a LAN", "Switch"],
	["Tool that checks if a host is reachable", "ping"], ["Private range 192.168.x.x is defined by", "RFC 1918"],
]
const DATABASES := [
	["SQL keyword to read rows", "SELECT"], ["SQL keyword to filter rows", "WHERE"],
	["SQL keyword to combine rows from two tables", "JOIN"], ["SQL keyword to add rows", "INSERT"],
	["SQL keyword to change existing rows", "UPDATE"], ["SQL keyword to sort results", "ORDER BY"],
	["SQL keyword to aggregate by a column", "GROUP BY"], ["Column that uniquely identifies a row", "Primary key"],
	["Column that refers to another table's key", "Foreign key"], ["Speeds up lookups on a column", "Index"],
	["All-or-nothing group of operations", "Transaction"], ["Filtering after GROUP BY", "HAVING"],
	["Removing duplicate data by splitting tables", "Normalization"], ["ACID: the 'I' stands for", "Isolation"],
]
const SECURITY := [
	["Tricking users into giving up passwords by fake email", "Phishing"],
	["Injecting database commands through a form field", "SQL injection"],
	["Flooding a server so real users cannot reach it", "Denial of service"],
	["Running attacker script in another user's browser", "Cross-site scripting"],
	["Proving identity with two different factors", "Two-factor authentication"],
	["One-way function for storing passwords", "Hashing (with salt)"],
	["Encryption that uses a public and a private key", "Asymmetric encryption"],
	["Encryption that uses one shared key", "Symmetric encryption"],
	["Malware that encrypts files and demands payment", "Ransomware"],
	["Giving each account only the access it needs", "Least privilege"],
	["Software that filters network traffic by rules", "Firewall"],
	["Random data added to a password before hashing", "Salt"],
]
const OS_FACTS := [
	["A program in execution", "Process"], ["Lightweight unit of execution inside a process", "Thread"],
	["Two processes each waiting for the other's lock", "Deadlock"], ["Moving pages between RAM and disk", "Paging / swapping"],
	["Core of the OS that manages hardware", "Kernel"], ["Signal from hardware that needs attention", "Interrupt"],
	["Switching the CPU from one process to another", "Context switch"], ["Lock that lets one thread in at a time", "Mutex"],
	["Counter-based synchronization primitive", "Semaphore"], ["Scheduling where each process gets a time slice in turn", "Round robin"],
]
const HARDWARE := [
	["Executes instructions", "CPU"], ["Fast, volatile working memory", "RAM"], ["Persistent solid-state storage", "SSD"],
	["Specialized for parallel graphics math", "GPU"], ["Main circuit board", "Motherboard"],
	["Converts wall AC power to DC for components", "Power supply"], ["Tiny fast memory on the CPU", "Cache"],
	["Firmware that starts the computer", "BIOS / UEFI"], ["8 bits", "1 byte"], ["1024 bytes", "1 KiB"],
]
const SOFTWARE_ENG := [
	["Tracking changes to code over time", "Version control"], ["Testing one function in isolation", "Unit test"],
	["Automatically building and testing every change", "Continuous integration"], ["Restructuring code without changing behavior", "Refactoring"],
	["Short development cycle in Agile", "Sprint"], ["Peer reading a change before merging", "Code review"],
	["Bundling a dependency's exact versions", "Lock file"], ["Fixing a defect", "Bug fix"],
	["Describes what a module offers to other code", "Interface / API"], ["Write the test before the code", "Test-driven development"],
]
const AI := [
	["Learning from labeled examples", "Supervised learning"], ["Finding structure in unlabeled data", "Unsupervised learning"],
	["Learning from rewards and penalties", "Reinforcement learning"], ["Model memorizes training data and fails on new data", "Overfitting"],
	["Data held back to measure performance", "Test set"], ["Algorithm that minimizes loss by following the slope", "Gradient descent"],
	["Predicting a category", "Classification"], ["Predicting a number", "Regression"],
	["Grouping similar points without labels", "Clustering"], ["Layers of weighted sums and activations", "Neural network"],
]
const IT := [
	["First step when a user's PC is slow", "Check what is using CPU and memory"],
	["User cannot reach any website but can ping 8.8.8.8", "DNS problem"],
	["Printer shows offline", "Check its power, cable or Wi-Fi, then the print queue"],
	["Forgotten password", "Verify identity, then reset it"],
	["Laptop will not power on", "Try a known-good charger and hold power 30 s"],
	["Self-assigned 169.254.x.x address", "DHCP failed"],
	["Suspicious email attachment", "Do not open it; report it"],
	["Blue screen after a driver update", "Roll back the driver"],
	["Files accidentally deleted on a share", "Restore from backup"],
	["Wi-Fi drops in one room only", "Signal coverage / interference"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	match topic:
		"binary":
			var n := rng.randi_range(3, 15 + lvl * 50)
			if rng.randf() < 0.5:
				return MC.build(rng, "Binary %s in decimal?" % _bin(n), n, MC.near_ints(rng, n, 4))
			return MC.build(rng, "Decimal %d in binary?" % n, _bin(n), [_bin(n + 1), _bin(n - 1), _bin(n ^ 2), _bin(n << 1), _bin(n ^ 1)])
		"hex":
			var n := rng.randi_range(10, 255 + lvl * 300)
			if rng.randf() < 0.5:
				return MC.build(rng, "Hex 0x%X in decimal?" % n, n, MC.near_ints(rng, n, 16))
			return MC.build(rng, "Decimal %d in hex?" % n, "0x%X" % n, ["0x%X" % (n + 1), "0x%X" % (n + 16), "0x%X" % (n - 1), "0x%d" % n])
		"boolean":
			var a := rng.randf() < 0.5; var b := rng.randf() < 0.5; var c := rng.randf() < 0.5
			var forms := [
				["(A AND B) OR C", (a and b) or c], ["A AND (B OR C)", a and (b or c)],
				["NOT A OR B", (not a) or b], ["A XOR B", a != b], ["NOT (A AND C)", not (a and c)],
				["(A OR B) AND NOT C", (a or b) and not c], ["A XOR (B AND C)", a != (b and c)],
			]
			var f: Array = MC.pick(rng, forms)
			return MC.build(rng, "A=%s, B=%s, C=%s. What is %s?" % [_tf(a), _tf(b), _tf(c), f[0]], _tf(f[1]), [_tf(not f[1]), "Error", "Undefined"])
		"loops":
			var start := rng.randi_range(0, 5); var stop := rng.randi_range(start + 3, start + 10 + lvl * 2); var step := rng.randi_range(1, 3)
			var total := 0
			var count := 0
			for i in range(start, stop, step):
				total += i
				count += 1
			if rng.randf() < 0.5:
				return MC.build(rng, "total = 0\nfor i in range(%d, %d, %d): total += i\nWhat is total?" % [start, stop, step], total,
					[total + stop, total - start, total + step, count], "range stops before %d." % stop)
			return MC.build(rng, "How many times does this run?\nfor i in range(%d, %d, %d): ..." % [start, stop, step], count,
				[count + 1, count - 1, (stop - start), (stop - start) / step + 1 if (stop - start) % step == 0 else count + 2])
		"bitwise":
			var a := rng.randi_range(1, 31); var b := rng.randi_range(1, 31)
			var op: String = MC.pick(rng, ["&", "|", "^", "<<", ">>"])
			var r: int
			match op:
				"&": r = a & b
				"|": r = a | b
				"^": r = a ^ b
				"<<": b = rng.randi_range(1, 3); r = a << b
				_: b = rng.randi_range(1, 3); r = a >> b
			return MC.build(rng, "What is %d %s %d?" % [a, op, b], r, [a & b, a | b, a ^ b, a + b, a * 2, a / 2].filter(func(v): return v != r))
		"recursion":
			if rng.randf() < 0.5:
				var n := rng.randi_range(3, 7)
				var f := 1
				for i in range(2, n + 1):
					f *= i
				return MC.build(rng, "def f(n): return 1 if n <= 1 else n * f(n - 1)\nWhat is f(%d)?" % n, f, [f / n, f * (n + 1), n * n, f + n])
			var k := rng.randi_range(4, 12)
			var x := 0; var y := 1
			for i in k:
				var t := x + y; x = y; y = t
			return MC.build(rng, "fib(0)=0, fib(1)=1, fib(n)=fib(n−1)+fib(n−2). What is fib(%d)?" % k, x, [y, x + 1, y - x, x - 1])
		"arrays":
			var arr := []
			for i in rng.randi_range(5, 8):
				arr.append(rng.randi_range(1, 50))
			var i := rng.randi_range(0, arr.size() - 1)
			if rng.randf() < 0.6:
				return MC.build(rng, "a = %s\nWhat is a[%d]?" % [str(arr), i], arr[i], [arr[(i + 1) % arr.size()], arr[i - 1], i, arr.size()], "Indexes start at 0.")
			return MC.build(rng, "a = %s\nWhat is a[-1]?" % str(arr), arr[-1], [arr[0], arr[-2], arr.size(), "Error"])
		"big_o":
			return MC.from_bank(rng, BIG_O, "Time complexity: %s?", 0, 1)
		"data_structures":
			return MC.both_ways(rng, STRUCTURES, "Which structure: %s?", "Which best describes \"%s\"?")
		"sorting":
			var arr := []
			for i in 5:
				arr.append(rng.randi_range(1, 40))
			var pass_arr := arr.duplicate()
			for j in pass_arr.size() - 1:
				if pass_arr[j] > pass_arr[j + 1]:
					var t: int = pass_arr[j]; pass_arr[j] = pass_arr[j + 1]; pass_arr[j + 1] = t
			var s := arr.duplicate(); s.sort()
			var rev := s.duplicate(); rev.reverse()
			return MC.build(rng, "%s after ONE bubble sort pass (ascending)?" % str(arr), str(pass_arr), [str(s), str(arr), str(rev), str(pass_arr.slice(1) + [pass_arr[0]])], "One pass bubbles the largest value to the end.")
		"networking":
			return MC.from_bank(rng, NETWORK, "%s?", 0, 1)
		"databases":
			return MC.from_bank(rng, DATABASES, "%s?", 0, 1)
		"security":
			return MC.both_ways(rng, SECURITY, "Which term: %s?", "Which best describes \"%s\"?")
		"os":
			return MC.both_ways(rng, OS_FACTS, "Which OS concept: %s?", "Which best describes \"%s\"?")
		"hardware":
			return MC.both_ways(rng, HARDWARE, "Which is it: %s?", "Which best describes \"%s\"?")
		"software_eng":
			return MC.both_ways(rng, SOFTWARE_ENG, "Which practice: %s?", "Which best describes \"%s\"?")
		"ai":
			return MC.both_ways(rng, AI, "Which ML term: %s?", "Which best describes \"%s\"?")
		"it_support":
			return MC.from_bank(rng, IT, "Help desk: %s. Best answer?", 0, 1)
	return MC.build(rng, "1 + 1 in binary?", "10", ["11", "2", "01"])

func _bin(n: int) -> String:
	if n <= 0:
		return "0"
	var s := ""
	while n > 0:
		s = str(n & 1) + s
		n >>= 1
	return s

func _tf(v: bool) -> String:
	return "TRUE" if v else "FALSE"
