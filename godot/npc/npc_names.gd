## Name pools for Cathedral Mount residents. Invented town, ordinary American mix.
class_name NpcNames
extends RefCounted

const MALE := ["James","Michael","David","John","Robert","William","Daniel","Matthew","Joseph","Christopher","Andrew","Joshua","Ryan","Tyler","Brandon","Jacob","Nathan","Ethan","Caleb","Logan","Mason","Owen","Wyatt","Carter","Isaiah","Jordan","Marcus","Darius","Andre","Malik","Terrence","Jamal","Luis","Carlos","Diego","Miguel","Javier","Mateo","Ángel","Rafael","Wei","Jun","Kevin","Hiro","Min-jun","Arjun","Rohan","Vikram","Sanjay","Omar","Yusuf","Samir","Elijah","Henry","Samuel","Thomas","Benjamin","Charles","George","Walter","Harold","Eugene","Russell","Dale","Wayne","Clint","Reid","Beau","Colby","Hunter","Grady","Silas","Emmett","Theo","Felix","Kofi","Kwame","Tobi","Emeka","Liam","Noah","Aiden","Connor","Patrick"]
const FEMALE := ["Mary","Jennifer","Elizabeth","Sarah","Jessica","Ashley","Emily","Hannah","Madison","Abigail","Olivia","Emma","Sophia","Ava","Chloe","Grace","Lily","Zoe","Natalie","Brooke","Kayla","Morgan","Taylor","Lauren","Megan","Rachel","Rebecca","Keisha","Imani","Aaliyah","Jasmine","Tiana","Monique","Destiny","Maria","Sofia","Camila","Valentina","Lucía","Isabel","Gabriela","Daniela","Mei","Yuna","Hana","Ji-woo","Priya","Ananya","Divya","Kavya","Leila","Amira","Noor","Fatima","Margaret","Dorothy","Betty","Ruth","Frances","Evelyn","Shirley","Carolyn","Darlene","Tammy","Crystal","Amber","Savannah","Caroline","Harper","Ellie","Ivy","Nora","Adaeze","Ngozi","Ama","Esi","Claire","Maeve","Siobhan","Ingrid","Freya","Tessa","Willa"]
const LAST := ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin","Lee","Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson","Walker","Young","Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores","Green","Adams","Nelson","Baker","Hall","Rivera","Campbell","Mitchell","Carter","Roberts","Phillips","Evans","Turner","Parker","Collins","Edwards","Stewart","Morris","Murphy","Cook","Rogers","Morgan","Peterson","Cooper","Reed","Bailey","Bell","Gomez","Kelly","Howard","Ward","Cox","Diaz","Richardson","Wood","Watson","Brooks","Bennett","Gray","James","Reyes","Cruz","Hughes","Price","Myers","Long","Foster","Sanders","Ross","Morales","Powell","Sullivan","Russell","Ortiz","Jenkins","Gutierrez","Perry","Butler","Barnes","Fisher","Henderson","Coleman","Simmons","Patterson","Jordan","Reynolds","Hamilton","Graham","Kim","Gonzales","Alexander","Ramos","Wallace","Griffin","West","Cole","Hayes","Chavez","Gibson","Bryant","Ellis","Stevens","Murray","Ford","Marshall","Owens","McDonald","Harrison","Ruiz","Kennedy","Wells","Alvarez","Woods","Mendoza","Castillo","Olson","Webb","Washington","Tucker","Freeman","Burns","Henry","Vasquez","Snyder","Simpson","Crawford","Jimenez","Porter","Mason","Shaw","Gordon","Wagner","Hunter","Romero","Hicks","Dixon","Hunt","Palmer","Robertson","Black","Holmes","Stone","Meyer","Boyd","Mills","Warren","Fox","Rose","Rice","Moreno","Schmidt","Patel","Shah","Chen","Wang","Liu","Zhang","Park","Choi","Tanaka","Okafor","Mensah","Haddad","Khan","Ali","Pemberton","Whitfield","Ashby","Lassiter","Honeycutt","Pruitt","Tillman","Strickland","Faircloth","Barefoot","Tart","Godwin","Jernigan","Hatcher"]
const MIDDLE_INITIALS := "ABCDEFGHIJKLMNOPRSTW"

# Extra pools used more often for some backgrounds, so names fit the person.
const HISPANIC_LAST := ["Garcia","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Perez","Sanchez","Ramirez","Torres","Flores","Rivera","Gomez","Diaz","Reyes","Cruz","Morales","Ortiz","Gutierrez","Chavez","Ramos","Ruiz","Alvarez","Mendoza","Castillo","Jimenez","Moreno","Vasquez","Romero","Herrera","Medina","Aguilar","Vargas","Castro","Salazar"]
const ASIAN_LAST := ["Nguyen","Kim","Lee","Park","Choi","Chen","Wang","Liu","Zhang","Li","Huang","Yang","Wu","Tanaka","Sato","Suzuki","Patel","Shah","Singh","Kumar","Gupta","Reddy","Iyer","Rao","Tran","Pham","Le","Vu","Lin","Cho","Kang","Desai","Mehta"]
const HISPANIC_MALE := ["Luis","Carlos","Diego","Miguel","Javier","Mateo","Ángel","Rafael","José","Juan","Alejandro","Andrés","Daniel","Santiago","Emilio","Marco"]
const HISPANIC_FEMALE := ["Maria","Sofia","Camila","Valentina","Lucía","Isabel","Gabriela","Daniela","Ana","Elena","Paola","Ximena","Carmen","Natalia","Mariana","Andrea"]
const ASIAN_MALE := ["Wei","Jun","Kevin","Hiro","Min-jun","Arjun","Rohan","Vikram","Sanjay","Eric","Brian","Kenji","Anh","Tuan","Dev","Aditya","Daniel","Jason"]
const ASIAN_FEMALE := ["Mei","Yuna","Hana","Ji-woo","Priya","Ananya","Divya","Kavya","Grace","Michelle","Linh","Mai","Sakura","Esther","Riya","Jenny","Vivian","Olivia"]
const INTERNATIONAL_MALE := ["Kofi","Kwame","Tobi","Emeka","Omar","Yusuf","Samir","Felix","Lukas","Mateo","Arjun","Wei","Jun","Hiro"]
const INTERNATIONAL_FEMALE := ["Adaeze","Ngozi","Ama","Esi","Leila","Amira","Noor","Fatima","Ingrid","Freya","Mei","Priya","Yuna","Sofia"]
const INTERNATIONAL_LAST := ["Okafor","Mensah","Haddad","Khan","Ali","Schmidt","Müller","Rossi","Dubois","Chen","Wang","Patel","Tanaka","Silva","Santos","Adeyemi","Boateng","Hassan","Novak","Kowalski"]


static func pick(sex: String, ethnicity: String, rng: RandomNumberGenerator) -> Array:
	var firsts: Array = MALE if sex == "male" else FEMALE
	var lasts: Array = LAST
	var r := rng.randf()
	match ethnicity:
		"hispanic":
			if r < 0.8:
				firsts = HISPANIC_MALE if sex == "male" else HISPANIC_FEMALE
				lasts = HISPANIC_LAST
		"asian":
			if r < 0.8:
				firsts = ASIAN_MALE if sex == "male" else ASIAN_FEMALE
				lasts = ASIAN_LAST
		"international":
			firsts = INTERNATIONAL_MALE if sex == "male" else INTERNATIONAL_FEMALE
			lasts = INTERNATIONAL_LAST
	return [firsts[rng.randi() % firsts.size()], lasts[rng.randi() % lasts.size()]]
