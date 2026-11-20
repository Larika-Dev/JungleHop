extends PCMinigame
## ONSU grading: compare answers with the key, type the score and letter.

const STUDENTS := ["A. Ramos", "B. Kowalski", "C. Mensah", "D. Park", "E. Laurent", "F. Haddad", "G. O'Neill", "H. Sato"]


func _app_name() -> String:
	return "%s  ·  MATH 110" % company_name("ONSU")


func _make_task() -> Dictionary:
	var n := 8 + int(difficulty * 4)
	var key := []
	var ans := []
	var correct := 0
	for i in n:
		var k: String = pick(["A", "B", "C", "D"])
		key.append(k)
		var a: String = k if rng.randf() < 0.72 else pick(["A", "B", "C", "D"])
		ans.append(a)
		if a == k:
			correct += 1
	var pct := 100.0 * correct / n
	var letter := "A" if pct >= 90 else "B" if pct >= 80 else "C" if pct >= 70 else "D" if pct >= 60 else "F"
	var s := "[b]Quiz 4[/b]  ·  %s\n\n[code]#    " % pick(STUDENTS)
	for i in n:
		s += "%-3d" % (i + 1)
	s += "\nKey  "
	for k in key:
		s += "%-3s" % k
	s += "\nAns  "
	for a in ans:
		s += "%-3s" % a
	s += "[/code]"
	par_seconds = 10.0 + n
	return {"screen": s, "side": "[b]Scale[/b]\nA 90%%+\nB 80%%+\nC 70%%+\nD 60%%+\nF below 60%%\n\n%d questions." % n, "fields": [
		{"label": "Number correct", "answer": correct, "kind": "number"},
		{"label": "Letter grade", "answer": letter, "kind": "text"},
	]}
