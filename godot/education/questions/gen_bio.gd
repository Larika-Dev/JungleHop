extends RefCounted
## Biology question generator.

const MC := preload("res://education/questions/mc.gd")

const TOPICS := {
	"dna": "DNA pairing", "transcription": "Transcription", "codons": "The genetic code",
	"punnett": "Mendelian genetics", "cells": "Cell structures", "division": "Mitosis and meiosis",
	"ecology": "Ecology and energy", "taxonomy": "Classification", "anatomy": "Human anatomy",
	"evolution": "Evolution", "microbio": "Microbiology", "photosynthesis": "Photosynthesis and respiration",
	"physiology": "Physiology", "botany": "Plant biology", "immunology": "Immunology",
}

const DNA_PAIR := {"A": "T", "T": "A", "C": "G", "G": "C"}
const RNA_PAIR := {"A": "U", "T": "A", "C": "G", "G": "C"}
const CODONS := {
	"AUG": "Methionine (start)", "UUU": "Phenylalanine", "UGG": "Tryptophan", "GGC": "Glycine",
	"GCU": "Alanine", "CAU": "Histidine", "AAA": "Lysine", "GAU": "Aspartic acid", "UCU": "Serine",
	"CCC": "Proline", "UAC": "Tyrosine", "CGU": "Arginine", "UAA": "Stop", "UAG": "Stop",
	"UGA": "Stop", "GUU": "Valine", "AUU": "Isoleucine", "CUU": "Leucine", "ACU": "Threonine",
	"UGU": "Cysteine", "GAA": "Glutamic acid", "CAA": "Glutamine", "AAU": "Asparagine",
}
const CELLS := [
	["Makes most of the cell's ATP", "Mitochondrion"], ["Holds the DNA in eukaryotes", "Nucleus"],
	["Builds proteins", "Ribosome"], ["Modifies and packages proteins", "Golgi apparatus"],
	["Rough membrane network studded with ribosomes", "Rough endoplasmic reticulum"],
	["Makes lipids and detoxifies", "Smooth endoplasmic reticulum"], ["Digests waste with enzymes", "Lysosome"],
	["Site of photosynthesis", "Chloroplast"], ["Rigid outer layer of plant cells", "Cell wall"],
	["Controls what enters and leaves the cell", "Cell membrane"], ["Large water store in plant cells", "Central vacuole"],
	["Builds ribosomes inside the nucleus", "Nucleolus"], ["Protein scaffold that shapes the cell", "Cytoskeleton"],
	["Organizes spindle fibers in animal cells", "Centriole"],
]
const DIVISION := [
	["Chromosomes line up in the middle", "Metaphase"], ["Sister chromatids pull apart", "Anaphase"],
	["Chromatin condenses into chromosomes", "Prophase"], ["Nuclear envelopes re-form", "Telophase"],
	["Cytoplasm splits in two", "Cytokinesis"], ["Crossing over between homologs", "Prophase I of meiosis"],
	["Produces two identical diploid cells", "Mitosis"], ["Produces four haploid gametes", "Meiosis"],
	["DNA is copied", "S phase"], ["Homologous pairs separate", "Anaphase I of meiosis"],
]
const TAXONOMY := [
	["Domain", "Kingdom"], ["Kingdom", "Phylum"], ["Phylum", "Class"], ["Class", "Order"],
	["Order", "Family"], ["Family", "Genus"], ["Genus", "Species"],
]
const KINGDOMS := [
	["Mushrooms and yeasts", "Fungi"], ["Oak trees and mosses", "Plantae"], ["Humans and insects", "Animalia"],
	["E. coli and other bacteria", "Bacteria"], ["Amoebas and algae (mostly)", "Protista"],
	["Microbes from hot springs that are not bacteria", "Archaea"],
]
const ANATOMY := [
	["Pumps blood through the body", "Heart"], ["Exchanges oxygen and CO₂", "Lungs"], ["Filters blood and makes urine", "Kidneys"],
	["Makes bile and stores glycogen", "Liver"], ["Releases insulin", "Pancreas"], ["Absorbs most nutrients", "Small intestine"],
	["Absorbs water from waste", "Large intestine"], ["Largest organ of the body", "Skin"], ["Longest bone in the body", "Femur"],
	["Connects muscle to bone", "Tendon"], ["Connects bone to bone", "Ligament"], ["Controls balance and coordination", "Cerebellum"],
	["Carries oxygen in red blood cells", "Hemoglobin"], ["Stores urine", "Bladder"], ["Filters lymph and stores white cells", "Spleen"],
	["Number of chambers in the human heart", "4"], ["Number of bones in the adult human body", "206"],
	["Large muscle on the back of the lower leg", "Gastrocnemius (calf)"],
]
const EVOLUTION := [
	["Proposed natural selection with Wallace", "Charles Darwin"], ["Structures with shared ancestry but different uses", "Homologous structures"],
	["Similar features from different ancestries", "Analogous structures"], ["Random change in allele frequency in small populations", "Genetic drift"],
	["Movement of alleles between populations", "Gene flow"], ["Formation of a new species", "Speciation"],
	["Remnant structures with little function", "Vestigial structures"], ["Change in DNA sequence", "Mutation"],
	["Organisms better suited leave more offspring", "Natural selection"], ["Dated using radioactive decay", "Radiometric dating of fossils"],
]
const MICRO := [
	["Bacterial shape: spherical", "Coccus"], ["Bacterial shape: rod", "Bacillus"], ["Bacterial shape: spiral", "Spirillum"],
	["Stains purple: thick peptidoglycan wall", "Gram-positive"], ["Stains pink: thin wall plus outer membrane", "Gram-negative"],
	["Needs a host cell to replicate", "Virus"], ["Infectious misfolded protein", "Prion"], ["Kills bacteria, not viruses", "Antibiotics"],
	["Virus that infects bacteria", "Bacteriophage"], ["Circular extra DNA in bacteria", "Plasmid"],
	["Bacterial reproduction by splitting", "Binary fission"],
]
const PHOTO := [
	["Gas plants take in for photosynthesis", "Carbon dioxide"], ["Gas released by photosynthesis", "Oxygen"],
	["Pigment that absorbs light", "Chlorophyll"], ["Stage that splits water", "Light-dependent reactions"],
	["Cycle that fixes carbon into sugar", "Calvin cycle"], ["Energy currency of the cell", "ATP"],
	["First stage of cellular respiration, in the cytoplasm", "Glycolysis"], ["Respiration stage that makes the most ATP", "Electron transport chain"],
	["Respiration without oxygen in muscles makes", "Lactic acid"], ["Yeast fermentation makes", "Ethanol and CO₂"],
]
const PHYSIO := [
	["Keeping a stable internal environment", "Homeostasis"], ["Hormone that lowers blood sugar", "Insulin"],
	["Hormone that raises blood sugar", "Glucagon"], ["Gland called the 'master gland'", "Pituitary"],
	["Fight-or-flight hormone", "Adrenaline (epinephrine)"], ["Cells that carry nerve signals", "Neurons"],
	["Gap between two neurons", "Synapse"], ["Smallest blood vessels", "Capillaries"],
	["Vessels carrying blood away from the heart", "Arteries"], ["Muscle that drives breathing", "Diaphragm"],
	["Tiny air sacs in the lungs", "Alveoli"], ["Filtering units of the kidney", "Nephrons"],
]
const BOTANY := [
	["Pores on leaves for gas exchange", "Stomata"], ["Carries water up from the roots", "Xylem"],
	["Carries sugars around the plant", "Phloem"], ["Growth toward light", "Phototropism"],
	["Plant with seeds in fruit", "Angiosperm"], ["Plant with naked seeds, like pines", "Gymnosperm"],
	["Male part of a flower", "Stamen"], ["Female part of a flower", "Pistil"],
	["Loss of water vapor from leaves", "Transpiration"], ["Hormone that promotes ripening", "Ethylene"],
]
const IMMUNO := [
	["Proteins that tag specific invaders", "Antibodies"], ["Cells that make antibodies", "B cells (plasma cells)"],
	["Cells that kill infected cells", "Cytotoxic T cells"], ["Cells that engulf invaders", "Macrophages"],
	["Molecule recognized by the immune system", "Antigen"], ["Trains immunity with a harmless form of a pathogen", "Vaccine"],
	["Immune system attacks the body's own cells", "Autoimmunity"], ["Overreaction to a harmless substance", "Allergy"],
	["First, non-specific defense", "Innate immunity"], ["Specific defense with memory", "Adaptive immunity"],
]

func make(topic: String, rng: RandomNumberGenerator, lvl: int) -> Dictionary:
	match topic:
		"dna":
			var s := _strand(rng, 5 + lvl)
			var right := _pair(s, DNA_PAIR)
			return MC.build(rng, "Complementary DNA strand of %s?" % s, right,
				[_pair(s, RNA_PAIR), s, _rev(right), _mutate(rng, right)], "A pairs with T, C pairs with G.")
		"transcription":
			var s := _strand(rng, 5 + lvl)
			var right := _pair(s, RNA_PAIR)
			return MC.build(rng, "mRNA transcribed from template DNA %s?" % s, right,
				[_pair(s, DNA_PAIR), s.replace("T", "U"), _rev(right), _mutate(rng, right)], "In RNA, uracil (U) replaces thymine.")
		"codons":
			var keys := CODONS.keys()
			var c: String = MC.pick(rng, keys)
			var wrong := []
			for k in MC.shuffle(rng, keys):
				if CODONS[k] != CODONS[c]:
					wrong.append(CODONS[k])
			return MC.build(rng, "Which amino acid does the mRNA codon %s code for?" % c, CODONS[c], wrong)
		"punnett":
			var crosses := [
				["Aa × Aa", "dominant", "3/4"], ["Aa × Aa", "recessive", "1/4"], ["Aa × aa", "dominant", "1/2"],
				["Aa × aa", "recessive", "1/2"], ["AA × aa", "dominant", "1"], ["AA × Aa", "recessive", "0"],
				["aa × aa", "recessive", "1"], ["AA × AA", "dominant", "1"],
			]
			var x: Array = MC.pick(rng, crosses)
			if lvl >= 3 and rng.randf() < 0.5:
				return MC.build(rng, "AaBb × AaBb (independent genes). Fraction showing both recessive traits?", "1/16", ["1/4", "9/16", "3/16", "1/8"], "1/4 × 1/4.")
			return MC.build(rng, "Cross %s. Fraction of offspring with the %s phenotype?" % [x[0], x[1]], x[2], ["3/4", "1/4", "1/2", "1", "0"])
		"cells":
			return MC.both_ways(rng, CELLS, "Which structure: %s?", "What does the %s do?")
		"division":
			return MC.from_bank(rng, DIVISION, "Which stage or process: %s?", 0, 1)
		"ecology":
			var e := rng.randi_range(1, 9) * pow(10, rng.randi_range(3, 5))
			var steps := rng.randi_range(1, 3)
			var names := ["primary consumers", "secondary consumers", "tertiary consumers"]
			var r := e * pow(0.1, steps)
			return MC.build(rng, "Producers capture %s kcal. About how much reaches %s (10%% rule)?" % [MC._fmt(e), names[steps - 1]], r,
				[e * pow(0.1, steps - 1) if steps > 1 else e * 0.5, r * 0.1, e * 0.9, r * 2], "About 10% passes up each trophic level.")
		"taxonomy":
			if rng.randf() < 0.5:
				return MC.from_bank(rng, KINGDOMS, "Which group: %s?", 0, 1)
			return MC.from_bank(rng, TAXONOMY, "Which rank comes right below %s?", 0, 1)
		"anatomy":
			return MC.from_bank(rng, ANATOMY, "Anatomy: %s?", 0, 1)
		"evolution":
			return MC.from_bank(rng, EVOLUTION, "Which term or person: %s?", 0, 1)
		"microbio":
			return MC.both_ways(rng, MICRO, "%s?", "Which describes \"%s\"?")
		"photosynthesis":
			return MC.from_bank(rng, PHOTO, "%s?", 0, 1)
		"physiology":
			return MC.both_ways(rng, PHYSIO, "Which term: %s?", "What is the role of \"%s\"?")
		"botany":
			return MC.both_ways(rng, BOTANY, "Which term: %s?", "Which describes \"%s\"?")
		"immunology":
			return MC.both_ways(rng, IMMUNO, "Which term: %s?", "Which describes \"%s\"?")
	return MC.build(rng, "Basic unit of life?", "Cell", ["Atom", "Organ", "Tissue"])

func _strand(rng: RandomNumberGenerator, n: int) -> String:
	var s := ""
	for i in n:
		s += ["A", "T", "C", "G"][rng.randi_range(0, 3)]
	return s

func _pair(s: String, table: Dictionary) -> String:
	var out := ""
	for b in s:
		out += table[b]
	return out

func _rev(s: String) -> String:
	var out := ""
	for i in range(s.length() - 1, -1, -1):
		out += s[i]
	return out

func _mutate(rng: RandomNumberGenerator, s: String) -> String:
	var i := rng.randi_range(0, s.length() - 1)
	var bases := ["A", "C", "G"] if "U" in s else ["A", "T", "C", "G"]
	if "U" in s:
		bases.append("U")
	var b: String = s[i]
	while b == s[i]:
		b = bases[rng.randi_range(0, bases.size() - 1)]
	return s.substr(0, i) + b + s.substr(i + 1)
