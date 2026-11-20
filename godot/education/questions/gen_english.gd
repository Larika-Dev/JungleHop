extends RefCounted
## English question generator: vocabulary, usage, spelling, grammar,
## literature (public-domain works) and rhetoric.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"vocab": "Vocabulary", "synonyms": "Synonyms", "antonyms": "Antonyms", "usage": "Commonly confused words",
	"spelling": "Spelling", "devices": "Literary devices", "pos": "Parts of speech", "agreement": "Subject-verb agreement",
	"punctuation": "Punctuation", "authors": "Authors and works", "poetry": "Poetry and meter",
	"rhetoric": "Rhetoric", "genres": "Genres and forms", "grammar_terms": "Grammar terms",
}

# word, definition, synonym, antonym
const WORDS := [
	["benevolent", "Kind and generous", "kind", "cruel"], ["candid", "Truthful and straightforward", "frank", "evasive"],
	["diligent", "Careful and hardworking", "industrious", "lazy"], ["ephemeral", "Lasting a very short time", "fleeting", "permanent"],
	["frugal", "Careful with money", "thrifty", "wasteful"], ["gregarious", "Fond of company", "sociable", "reclusive"],
	["hostile", "Unfriendly and aggressive", "antagonistic", "friendly"], ["impartial", "Treating all sides equally", "neutral", "biased"],
	["jubilant", "Joyful and triumphant", "elated", "despondent"], ["lucid", "Clear and easy to understand", "clear", "confusing"],
	["meticulous", "Very careful about detail", "precise", "careless"], ["novice", "A beginner", "newcomer", "expert"],
	["obstinate", "Stubbornly refusing to change", "stubborn", "flexible"], ["pragmatic", "Practical rather than idealistic", "practical", "idealistic"],
	["quell", "To put an end to", "suppress", "provoke"], ["reticent", "Not revealing thoughts readily", "reserved", "talkative"],
	["scarce", "In short supply", "rare", "plentiful"], ["tenacious", "Holding firmly; persistent", "persistent", "yielding"],
	["ubiquitous", "Found everywhere", "omnipresent", "rare"], ["verbose", "Using too many words", "wordy", "concise"],
	["wary", "Cautious about danger", "cautious", "reckless"], ["zealous", "Full of eager enthusiasm", "fervent", "apathetic"],
	["ambiguous", "Open to more than one meaning", "unclear", "explicit"], ["brevity", "Shortness of time or words", "conciseness", "length"],
	["cordial", "Warm and friendly", "amiable", "cold"], ["deter", "To discourage from acting", "discourage", "encourage"],
	["feasible", "Possible to do", "viable", "impossible"],
	["haughty", "Arrogantly superior", "arrogant", "humble"], ["inept", "Lacking skill", "incompetent", "skilled"],
	["lethargic", "Sluggish and tired", "sluggish", "energetic"], ["mundane", "Ordinary and dull", "ordinary", "extraordinary"],
	["opulent", "Rich and luxurious", "lavish", "modest"], ["prudent", "Wise and careful about the future", "sensible", "rash"],
	["resilient", "Able to recover quickly", "tough", "fragile"], ["serene", "Calm and peaceful", "tranquil", "agitated"],
	["trivial", "Of little importance", "minor", "significant"], ["vivid", "Bright and intense", "striking", "dull"],
	["eloquent", "Fluent and persuasive in speech", "articulate", "inarticulate"], ["volatile", "Likely to change suddenly", "unstable", "stable"],
]
# sentence with ___, correct word, wrong words
const USAGE := [
	["___ going to the library after class.", "They're", ["Their", "There"]], ["The dog wagged ___ tail.", "its", ["it's", "its'"]],
	["She is taller ___ her brother.", "than", ["then", "that"]], ["The new law will ___ everyone.", "affect", ["effect", "afect"]],
	["The ___ of the storm was huge.", "effect", ["affect", "efect"]], ["___ welcome to join us.", "You're", ["Your", "Yore"]],
	["Don't ___ your keys again.", "lose", ["loose", "loss"]], ["I ___ your apology.", "accept", ["except", "expect"]],
	["Please put the books over ___.", "there", ["their", "they're"]], ["We walked ___ the park.", "through", ["threw", "thorough"]],
	["He gave me good ___.", "advice", ["advise", "advize"]], ["The ___ of the school spoke.", "principal", ["principle", "principel"]],
	["Write on the ___.", "stationery", ["stationary", "stationairy"]], ["___ is the umbrella?", "Whose", ["Who's", "Whos"]],
	["I have ___ books than you.", "fewer", ["less", "lesser"]], ["The team ___ been practicing.", "has", ["have", "having"]], ["She did ___ on the test.", "well", ["good", "goodly"]],
	["Between you and ___.", "me", ["I", "myself"]], ["It was ___ hot to run.", "too", ["to", "two"]],
]
# correct spelling (wrong spellings are generated)
const SPELL := [
	"accommodate", "necessary", "separate", "definitely", "embarrass", "occurrence", "rhythm", "conscience", "maintenance",
	"millennium", "privilege", "recommend", "receive", "believe", "calendar", "committee", "environment", "government",
	"guarantee", "independent", "library", "neighbor", "occasion", "parallel", "possession", "restaurant", "schedule",
	"tomorrow", "vacuum", "weird", "beginning", "address", "argument", "cemetery", "february", "gauge", "harass", "liaison",
]
const DEVICES := [
	["\"The wind whispered through the trees.\"", "Personification"], ["\"Her smile was sunshine.\"", "Metaphor"],
	["\"Brave as a lion.\"", "Simile"], ["\"I've told you a million times.\"", "Hyperbole"], ["\"Peter Piper picked a peck.\"", "Alliteration"],
	["\"The bees buzzed.\"", "Onomatopoeia"], ["A fire station burns down.", "Situational irony"], ["\"Deafening silence.\"", "Oxymoron"],
	["Early hints of what will happen later", "Foreshadowing"], ["A scene that jumps back in time", "Flashback"],
	["An object standing for an idea, like a dove for peace", "Symbol"], ["A reference to another famous work", "Allusion"],
	["\"The pen is mightier than the sword.\"", "Metonymy"], ["Repeating vowel sounds: \"the rain in Spain\"", "Assonance"],
	["The audience knows what a character does not", "Dramatic irony"], ["A character's speech alone on stage", "Soliloquy"],
]
# sentence, highlighted word, part of speech
const POS := [
	["The quick fox jumped.", "quick", "Adjective"], ["She sang beautifully.", "beautifully", "Adverb"], ["They ran home.", "ran", "Verb"],
	["The cat sat under the table.", "under", "Preposition"], ["Wow, that is tall!", "Wow", "Interjection"], ["I like tea and toast.", "and", "Conjunction"],
	["He forgot his keys.", "He", "Pronoun"], ["Happiness is contagious.", "Happiness", "Noun"], ["The bell rang loudly.", "bell", "Noun"],
	["We should leave now.", "leave", "Verb"], ["Run quickly!", "quickly", "Adverb"], ["The blue car stopped.", "blue", "Adjective"],
	["She walked across the bridge.", "across", "Preposition"], ["I wanted to go, but it rained.", "but", "Conjunction"],
	["Ouch, that hurt!", "Ouch", "Interjection"], ["They waved at us.", "us", "Pronoun"],
]
const AGREE := [
	["Each of the students ___ a book.", "has", ["have", "are having"]], ["The list of items ___ on the desk.", "is", ["are", "were being"]],
	["Neither the teacher nor the students ___ late.", "were", ["was", "is"]], ["Everybody ___ to win.", "wants", ["want", "are wanting"]],
	["The news ___ good today.", "is", ["are", "were"]], ["My friends and I ___ going.", "are", ["is", "am"]],
	["Mathematics ___ my favorite subject.", "is", ["are", "were"]], ["One of the dogs ___ barking.", "is", ["are", "were"]],
	["There ___ many reasons.", "are", ["is", "was"]], ["The jury ___ reached its verdict.", "has", ["have", "are"]],
]
const PUNCT := [
	["Choose the correct sentence.", "It's raining, so bring an umbrella.", ["Its raining, so bring an umbrella.", "It's raining so, bring an umbrella.", "Its' raining, so bring an umbrella."]],
	["Choose the correct sentence.", "I bought eggs, milk, and bread.", ["I bought eggs milk, and bread.", "I bought, eggs, milk and bread.", "I bought eggs; milk; and, bread."]],
	["Choose the correct sentence.", "She said, \"Let's go.\"", ["She said \"Let's go\".", "She said, \"Lets go.\"", "She said; \"Let's go.\""]],
	["Choose the correct sentence.", "I studied hard; I passed the exam.", ["I studied hard, I passed the exam.", "I studied hard I passed the exam.", "I studied; hard I passed the exam."]],
	["Choose the correct sentence.", "The students' grades were posted.", ["The student's grades were posted by all.", "The students grade's were posted.", "The students grades' were posted."]],
	["Choose the correct sentence.", "You need three things: paper, a pen, and time.", ["You need: three things paper, a pen, and time.", "You need three things; paper, a pen, and time.", "You need three things, paper: a pen, and time."]],
	["Choose the correct sentence.", "After dinner, we watched a movie.", ["After dinner we, watched a movie.", "After, dinner we watched a movie.", "After dinner; we watched a movie."]],
]
# public-domain works only
const AUTHORS := [
	["Pride and Prejudice", "Jane Austen"], ["Hamlet", "William Shakespeare"], ["Moby-Dick", "Herman Melville"],
	["Frankenstein", "Mary Shelley"], ["The Adventures of Huckleberry Finn", "Mark Twain"], ["Jane Eyre", "Charlotte Brontë"],
	["Wuthering Heights", "Emily Brontë"], ["Great Expectations", "Charles Dickens"], ["The Odyssey", "Homer"],
	["The Divine Comedy", "Dante Alighieri"], ["Don Quixote", "Miguel de Cervantes"], ["Leaves of Grass", "Walt Whitman"],
	["The Scarlet Letter", "Nathaniel Hawthorne"], ["Little Women", "Louisa May Alcott"], ["The Raven", "Edgar Allan Poe"],
	["Crime and Punishment", "Fyodor Dostoevsky"], ["War and Peace", "Leo Tolstoy"], ["The Canterbury Tales", "Geoffrey Chaucer"],
	["Narrative of the Life of Frederick Douglass", "Frederick Douglass"], ["The Great Gatsby", "F. Scott Fitzgerald"],
	["Dracula", "Bram Stoker"], ["Paradise Lost", "John Milton"], ["Walden", "Henry David Thoreau"], ["Macbeth", "William Shakespeare"],
]
const POETRY := [
	["Unstressed then stressed syllable (da-DUM)", "Iamb"], ["Stressed then unstressed (DUM-da)", "Trochee"],
	["Five iambs per line", "Iambic pentameter"], ["14-line poem with a set rhyme scheme", "Sonnet"],
	["Japanese 5-7-5 syllable poem", "Haiku"], ["Poetry without regular rhyme or meter", "Free verse"],
	["Unrhymed iambic pentameter", "Blank verse"], ["Two rhyming lines together", "Couplet"],
	["A four-line stanza", "Quatrain"], ["A long poem about heroic deeds", "Epic"], ["A poem mourning the dead", "Elegy"],
	["A lyric poem addressed to a subject, often in praise", "Ode"],
]
const RHETORIC := [
	["Appeal to credibility or character", "Ethos"], ["Appeal to emotion", "Pathos"], ["Appeal to logic and evidence", "Logos"],
	["Attacking the person instead of the argument", "Ad hominem"], ["Misrepresenting an argument to knock it down", "Straw man"],
	["Only two options when more exist", "False dilemma"], ["One step will inevitably lead to disaster", "Slippery slope"],
	["Everyone believes it, so it's true", "Bandwagon"], ["Assuming the conclusion in the premise", "Circular reasoning"],
	["The main claim of an essay", "Thesis"], ["Addressing the other side's argument", "Counterargument"],
]
const GENRES := [
	["A long fictional prose narrative", "Novel"], ["A story told through dialogue on stage", "Drama"],
	["A true account of someone's own life", "Autobiography"], ["A short story teaching a moral with animals", "Fable"],
	["A story set in an imagined future with advanced technology", "Science fiction"], ["A work mocking human folly", "Satire"],
	["A play with a sad downfall of the hero", "Tragedy"], ["A play with a happy ending, often humorous", "Comedy"],
	["A short nonfiction piece arguing a point", "Essay"], ["An imagined perfect society", "Utopia"],
]
const GRAMMAR := [
	["Group of words with a subject and a verb", "Clause"], ["Clause that can stand alone", "Independent clause"],
	["Two sentences joined with only a comma", "Comma splice"], ["Verb form ending in -ing used as a noun", "Gerund"],
	["The subject receives the action: \"The ball was thrown.\"", "Passive voice"], ["Word a pronoun refers to", "Antecedent"],
	["Modifier placed next to the wrong word", "Misplaced modifier"], ["Sentence missing a subject or main verb", "Sentence fragment"],
	["Noun that receives the action of the verb", "Direct object"], ["Words that work in pairs, like either/or", "Correlative conjunctions"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	match topic:
		"vocab":
			return MC.both_ways(rng, WORDS, "What does \"%s\" mean?", "Which word means \"%s\"?")
		"synonyms":
			var w: Array = MC.pick(rng, WORDS)
			var wrong := []
			for r in MC.shuffle(rng, WORDS):
				if r != w:
					wrong.append(r[2])
			wrong.insert(0, w[3])
			return MC.build(rng, "Closest in meaning to \"%s\"?" % w[0], w[2], wrong, w[1])
		"antonyms":
			var w2: Array = MC.pick(rng, WORDS)
			var wrong2 := [w2[2]]
			for r in MC.shuffle(rng, WORDS):
				if r != w2:
					wrong2.append(r[3])
			return MC.build(rng, "Opposite of \"%s\"?" % w2[0], w2[3], wrong2, w2[1])
		"usage", "agreement":
			var bank: Array = USAGE if topic == "usage" else AGREE
			var u: Array = MC.pick(rng, bank)
			var extra := ["Both are correct"]
			return MC.build(rng, "Fill the blank: %s" % u[0], u[1], u[2] + extra)
		"spelling":
			var word: String = MC.pick(rng, SPELL)
			var wrong3 := []
			for i in 12:
				var m := _misspell(rng, word)
				if m != word:
					wrong3.append(m)
			return MC.build(rng, "Which spelling is correct?", word, wrong3)
		"devices":
			return MC.from_bank(rng, DEVICES, "Which literary device: %s", 0, 1)
		"pos":
			var p: Array = MC.pick(rng, POS)
			return MC.build(rng, "In \"%s\", what part of speech is \"%s\"?" % [p[0], p[1]], p[2],
				["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Preposition", "Conjunction", "Interjection"])
		"punctuation":
			var q: Array = MC.pick(rng, PUNCT)
			return MC.build(rng, q[0], q[1], q[2])
		"authors":
			return MC.both_ways(rng, AUTHORS, "Who wrote %s?", "Which of these did %s write?")
		"poetry":
			return MC.both_ways(rng, POETRY, "Which term: %s?", "Which describes \"%s\"?")
		"rhetoric":
			return MC.both_ways(rng, RHETORIC, "Which term: %s?", "Which describes \"%s\"?")
		"genres":
			return MC.from_bank(rng, GENRES, "Which genre or form: %s?", 0, 1)
		"grammar_terms":
			return MC.from_bank(rng, GRAMMAR, "Which grammar term: %s?", 0, 1)
	return MC.build(rng, "Plural of \"child\"?", "children", ["childs", "childes", "childrens"])

func _misspell(rng: RandomNumberGenerator, w: String) -> String:
	var i := rng.randi_range(1, w.length() - 2)
	match rng.randi_range(0, 3):
		0: # drop a letter
			return w.substr(0, i) + w.substr(i + 1)
		1: # double a letter
			return w.substr(0, i) + w[i] + w.substr(i)
		2: # swap two letters
			return w.substr(0, i) + w[i + 1] + w[i] + w.substr(i + 2)
		_: # swap a vowel
			var vowels := "aeiou"
			for j in range(i, w.length()):
				if w[j] in vowels:
					var v := vowels[(vowels.find(w[j]) + 1 + rng.randi_range(0, 3)) % 5]
					return w.substr(0, j) + v + w.substr(j + 1)
			return w.substr(0, i) + w.substr(i + 1)
