extends RefCounted
class_name NationalNames

## Nombres y apellidos por REGIÓN cultural/lingüística — pedido explícito
## de Wilber: "investiga nombres y apellidos de esos países para crearlos
## y que sea más realista" (relleno sintético de selecciones sin
## suficientes jugadores reales, ver NationalTeamFactory._finish_squad).
## Nombres COMUNES reales de cada cultura, nunca de futbolistas
## específicos (regla de siempre, CLAUDE.md: nada de nombres de
## futbolistas reales) — la combinación al azar de nombre+apellido de 2
## listas genéricas nunca reproduce a una persona real puntual, igual
## criterio que ya usa WorldFactory._make_person_name() para el resto del
## mundo (esto NO reemplaza esas listas genéricas del mundo procedural,
## solo se usa para el relleno de SELECCIÓN por país, donde antes salía
## siempre el mismo pool "internacional" sin importar el país).
##
## No es 1 región por país (199 sería inmanejable) sino ~35 por
## afinidad lingüística/cultural real, mapeando cada país de
## Countries.ALL a la más cercana. Un país no listado explícitamente cae
## en _DEFAULT_REGION ("generic", el pool internacional de siempre).

const _DEFAULT_REGION := "generic"

const COUNTRY_REGION := {
	# --- Hispanoamérica + España ---
	"Argentina": "hispano", "México": "hispano", "Colombia": "hispano", "Chile": "hispano",
	"Perú": "hispano", "Venezuela": "hispano", "Ecuador": "hispano", "Bolivia": "hispano",
	"Paraguay": "hispano", "Uruguay": "hispano", "Cuba": "hispano", "República Dominicana": "hispano",
	"Guatemala": "hispano", "Honduras": "hispano", "El Salvador": "hispano", "Nicaragua": "hispano",
	"Costa Rica": "hispano", "Panamá": "hispano", "España": "hispano", "Andorra": "hispano",
	"Guinea Ecuatorial": "hispano",
	# --- Brasil / lusófonos ---
	"Brasil": "brasil",
	"Portugal": "portugal",
	"Angola": "lusoafrica", "Mozambique": "lusoafrica", "Cabo Verde": "lusoafrica",
	"Guinea-Bisáu": "lusoafrica", "Santo Tomé y Príncipe": "lusoafrica",
	# --- Italia ---
	"Italia": "italia", "San Marino": "italia", "Ciudad del Vaticano": "italia", "Malta": "italia",
	# --- Francia ---
	"Francia": "francia", "Mónaco": "francia",
	# --- Reino Unido / Irlanda / Oceanía anglosajona ---
	"Inglaterra": "britanico", "Escocia": "britanico", "Gales": "britanico",
	"Irlanda del Norte": "britanico", "Irlanda": "britanico",
	"Australia": "britanico", "Nueva Zelanda": "britanico",
	# --- Alemania / centroeuropa germánica ---
	"Alemania": "germanico", "Austria": "germanico", "Liechtenstein": "germanico", "Suiza": "germanico",
	# --- Benelux (neerlandés) ---
	"Países Bajos": "neerlandes", "Bélgica": "neerlandes", "Luxemburgo": "neerlandes",
	# --- Escandinavia ---
	"Suecia": "nordico", "Noruega": "nordico", "Dinamarca": "nordico",
	"Islandia": "nordico", "Finlandia": "nordico",
	# --- Europa del este / eslavos ---
	"Polonia": "eslavo", "República Checa": "eslavo", "Eslovaquia": "eslavo",
	"Ucrania": "eslavo", "Rusia": "eslavo", "Bielorrusia": "eslavo", "Moldavia": "eslavo",
	# --- Balcanes ---
	"Eslovenia": "balcanico", "Croacia": "balcanico", "Serbia": "balcanico",
	"Bosnia y Herzegovina": "balcanico", "Montenegro": "balcanico", "Macedonia del Norte": "balcanico",
	"Albania": "balcanico", "Kosovo": "balcanico", "Bulgaria": "balcanico", "Rumanía": "balcanico",
	"Grecia": "griego", "Chipre": "griego",
	"Hungría": "hungaro",
	"Estonia": "baltico", "Letonia": "baltico", "Lituania": "baltico",
	"Georgia": "caucaso", "Armenia": "caucaso", "Azerbaiyán": "caucaso",
	"Turquía": "turco",
	# --- Medio Oriente / norte de África (árabe) ---
	"Arabia Saudita": "arabe", "Emiratos Árabes Unidos": "arabe", "Catar": "arabe",
	"Kuwait": "arabe", "Baréin": "arabe", "Omán": "arabe", "Yemen": "arabe", "Irak": "arabe",
	"Siria": "arabe", "Líbano": "arabe", "Jordania": "arabe", "Palestina": "arabe",
	"Egipto": "arabe", "Libia": "arabe", "Túnez": "arabe", "Argelia": "arabe",
	"Marruecos": "arabe", "Sudán": "arabe", "Sudán del Sur": "arabe", "Mauritania": "arabe",
	"Irán": "persa", "Afganistán": "persa",
	"Israel": "hebreo",
	# --- Asia central ---
	"Kazajistán": "asia_central", "Uzbekistán": "asia_central", "Turkmenistán": "asia_central",
	"Kirguistán": "asia_central", "Tayikistán": "asia_central", "Mongolia": "asia_central",
	# --- África occidental anglófona ---
	"Nigeria": "africa_oeste_a", "Ghana": "africa_oeste_a", "Sierra Leona": "africa_oeste_a",
	"Liberia": "africa_oeste_a", "Gambia": "africa_oeste_a",
	# --- África occidental/central francófona ---
	"Senegal": "africa_oeste_f", "Malí": "africa_oeste_f", "Burkina Faso": "africa_oeste_f",
	"Costa de Marfil": "africa_oeste_f", "Guinea": "africa_oeste_f", "Níger": "africa_oeste_f",
	"Togo": "africa_oeste_f", "Benín": "africa_oeste_f", "Chad": "africa_oeste_f",
	"Camerún": "africa_oeste_f", "Gabón": "africa_oeste_f",
	"República del Congo": "africa_oeste_f", "República Democrática del Congo": "africa_oeste_f",
	"República Centroafricana": "africa_oeste_f",
	# --- África oriental ---
	"Kenia": "africa_este", "Tanzania": "africa_este", "Uganda": "africa_este",
	"Ruanda": "africa_este", "Burundi": "africa_este", "Etiopía": "africa_este",
	"Eritrea": "africa_este", "Yibuti": "africa_este", "Somalia": "africa_este",
	# --- África austral ---
	"Sudáfrica": "africa_sur", "Zimbabue": "africa_sur", "Zambia": "africa_sur",
	"Malaui": "africa_sur", "Namibia": "africa_sur", "Botsuana": "africa_sur",
	"Lesoto": "africa_sur", "Esuatini": "africa_sur", "Madagascar": "africa_sur",
	"Mauricio": "africa_sur", "Seychelles": "africa_sur", "Comoras": "africa_sur",
	# --- Asia del sur ---
	"India": "asia_sur", "Pakistán": "asia_sur", "Bangladés": "asia_sur",
	"Sri Lanka": "asia_sur", "Nepal": "asia_sur", "Bután": "asia_sur", "Maldivas": "asia_sur",
	# --- Asia oriental ---
	"China": "chino", "Japón": "japones", "Corea del Sur": "coreano", "Corea del Norte": "coreano",
	# --- Sudeste asiático ---
	"Vietnam": "vietnamita", "Filipinas": "filipino",
	"Tailandia": "sudeste_asia", "Laos": "sudeste_asia", "Camboya": "sudeste_asia",
	"Birmania": "sudeste_asia", "Timor Oriental": "sudeste_asia",
	"Indonesia": "malayo", "Malasia": "malayo", "Singapur": "malayo", "Brunéi": "malayo",
	# --- Oceanía (islas del Pacífico) ---
	"Fiyi": "pacifico", "Papúa Nueva Guinea": "pacifico", "Samoa": "pacifico",
	"Tonga": "pacifico", "Vanuatu": "pacifico", "Islas Salomón": "pacifico",
	"Kiribati": "pacifico", "Micronesia": "pacifico", "Palaos": "pacifico",
	"Islas Marshall": "pacifico", "Nauru": "pacifico", "Tuvalu": "pacifico",
	# --- Caribe anglófono ---
	"Jamaica": "caribe_a", "Trinidad y Tobago": "caribe_a", "Bahamas": "caribe_a",
	"Barbados": "caribe_a", "Guyana": "caribe_a", "Belice": "caribe_a",
	"Antigua y Barbuda": "caribe_a", "Dominica": "caribe_a", "Granada": "caribe_a",
	"San Cristóbal y Nieves": "caribe_a", "San Vicente y las Granadinas": "caribe_a",
	"Santa Lucía": "caribe_a", "Surinam": "caribe_a", "Curazao": "caribe_a",
	"Haití": "haiti",
	# --- Norteamérica anglófona ---
	"Estados Unidos": "usa", "Canadá": "usa",
}

const NAMES := {
	"hispano": {
		"first": ["Mateo", "Santiago", "Sebastián", "Diego", "Nicolás", "Alejandro", "Javier",
			"Andrés", "Emiliano", "Gonzalo", "Rodrigo", "Tomás", "Facundo", "Ignacio", "Valentín"],
		"last": ["González", "Rodríguez", "Fernández", "López", "Martínez", "Pérez", "Sánchez",
			"Ramírez", "Torres", "Flores", "Acosta", "Medina", "Vargas", "Castro", "Rojas"],
	},
	"brasil": {
		"first": ["Gabriel", "Lucas", "Matheus", "Rafael", "Bruno", "Thiago", "Vinícius",
			"Caio", "Everton", "Wesley", "Douglas", "Kaique", "Renan", "Fábio", "Marcos"],
		"last": ["Silva", "Santos", "Oliveira", "Souza", "Costa", "Pereira", "Almeida",
			"Ribeiro", "Carvalho", "Gomes", "Barbosa", "Rocha", "Dias", "Nascimento", "Teixeira"],
	},
	"portugal": {
		"first": ["João", "Miguel", "Tiago", "Rui", "Bruno", "Nuno", "André", "Pedro",
			"Ricardo", "Vítor", "Hugo", "Fábio", "Duarte", "Gonçalo", "Afonso"],
		"last": ["Ferreira", "Costa", "Pereira", "Marques", "Fonseca", "Cardoso", "Correia",
			"Machado", "Nunes", "Pinto", "Lopes", "Carvalho", "Simões", "Neves", "Alves"],
	},
	"lusoafrica": {
		"first": ["Zeca", "Ngola", "Nelson", "Edmilson", "Manecas", "Kalu", "Amido", "Djibril",
			"Osvaldo", "Bebé", "Tico", "Nando", "Fabrício", "Wilson", "Cabral"],
		"last": ["Mendes", "Cardoso", "Neto", "Vieira", "Baptista", "Semedo", "Fernandes",
			"Silva", "Gomes", "Rocha", "Nascimento", "Sanha", "Té", "Pina", "Lima"],
	},
	"italia": {
		"first": ["Marco", "Luca", "Andrea", "Matteo", "Alessandro", "Francesco", "Davide",
			"Simone", "Federico", "Riccardo", "Stefano", "Giovanni", "Lorenzo", "Emanuele", "Fabio"],
		"last": ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo",
			"Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti", "De Luca", "Mancini"],
	},
	"francia": {
		"first": ["Antoine", "Julien", "Nicolas", "Théo", "Hugo", "Mathis", "Lucas", "Kevin",
			"Alexandre", "Maxime", "Baptiste", "Adrien", "Rayan", "Enzo", "Yanis"],
		"last": ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Petit", "Durand",
			"Leroy", "Moreau", "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "Roux"],
	},
	"britanico": {
		"first": ["James", "Jack", "Harry", "Callum", "Oliver", "George", "Thomas", "Charlie",
			"Joshua", "Daniel", "Connor", "Ryan", "Liam", "Ethan", "Jamie"],
		"last": ["Smith", "Jones", "Taylor", "Brown", "Wilson", "Evans", "Thomas", "Roberts",
			"Walker", "Wright", "Robinson", "Campbell", "Stewart", "Murphy", "Clarke"],
	},
	"germanico": {
		"first": ["Lukas", "Maximilian", "Felix", "Jonas", "Tim", "Niklas", "Leon", "Julian",
			"Fabian", "Sebastian", "Moritz", "Simon", "Kevin", "David", "Florian"],
		"last": ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner",
			"Becker", "Hoffmann", "Schulz", "Koch", "Bauer", "Richter", "Klein", "Wolf"],
	},
	"neerlandes": {
		"first": ["Daan", "Sem", "Bram", "Lars", "Tim", "Ruben", "Sven", "Jesse", "Thijs",
			"Milan", "Wouter", "Niels", "Joris", "Kevin", "Stijn"],
		"last": ["De Jong", "Jansen", "De Vries", "Van den Berg", "Bakker", "Visser",
			"Smit", "Meijer", "De Boer", "Mulder", "Bos", "Peters", "Dekker", "Hendriks", "Kok"],
	},
	"nordico": {
		"first": ["Erik", "Lars", "Anders", "Magnus", "Oskar", "Emil", "Viktor", "Henrik",
			"Nils", "Sander", "Mikael", "Fredrik", "Jonas", "Axel", "Aksel"],
		"last": ["Andersson", "Johansson", "Karlsson", "Nilsson", "Eriksson", "Larsson",
			"Olsen", "Hansen", "Jensen", "Pedersen", "Nielsen", "Virtanen", "Korhonen", "Mäkinen", "Berg"],
	},
	"eslavo": {
		"first": ["Aleksandr", "Dmitri", "Ivan", "Mikhail", "Sergei", "Andrei", "Pavel",
			"Yuri", "Viktor", "Igor", "Piotr", "Tomasz", "Jakub", "Adam", "Oleksandr"],
		"last": ["Ivanov", "Petrov", "Sokolov", "Volkov", "Kovalenko", "Kowalski",
			"Nowak", "Wiśniewski", "Novák", "Kováč", "Shevchenko", "Bondarenko", "Sidorov", "Popov", "Melnyk"],
	},
	"balcanico": {
		"first": ["Marko", "Nikola", "Stefan", "Luka", "Ivan", "Milan", "Petar", "Dario",
			"Ante", "Bojan", "Ognjen", "Vlad", "Andrei", "Alban", "Ermal"],
		"last": ["Jovanović", "Petrović", "Marković", "Nikolić", "Popović", "Kovačević",
			"Horvat", "Kovač", "Ilić", "Stanković", "Radić", "Dimitrov", "Georgescu", "Krasniqi", "Hoxha"],
	},
	"griego": {
		"first": ["Giorgos", "Nikos", "Kostas", "Dimitris", "Yannis", "Panagiotis", "Vassilis",
			"Christos", "Andreas", "Stavros", "Michalis", "Alexis", "Thanos", "Petros", "Marios"],
		"last": ["Papadopoulos", "Papadakis", "Nikolaou", "Georgiou", "Ioannou", "Konstantinou",
			"Vasiliou", "Christodoulou", "Antoniou", "Dimou", "Angelidis", "Karagiannis", "Pappas", "Katsaros", "Michailidis"],
	},
	"hungaro": {
		"first": ["Bence", "Ádám", "Gábor", "Zoltán", "Balázs", "László", "Attila", "Márk",
			"Dávid", "Krisztián", "Tamás", "Norbert", "Roland", "Ferenc", "Gergő"],
		"last": ["Nagy", "Kovács", "Tóth", "Szabó", "Horváth", "Varga", "Kiss", "Molnár",
			"Németh", "Farkas", "Balogh", "Papp", "Takács", "Juhász", "Lakatos"],
	},
	"baltico": {
		"first": ["Andris", "Kristaps", "Roberts", "Mārtiņš", "Karlis", "Tautvydas", "Rokas",
			"Mantas", "Justas", "Kaarel", "Rasmus", "Markus", "Sander", "Mihkel", "Toomas"],
		"last": ["Bērziņš", "Ozols", "Kalniņš", "Balčiūnas", "Petrauskas", "Kazlauskas",
			"Tamm", "Saar", "Sepp", "Ivanovs", "Vasiliauskas", "Zariņš", "Krievs", "Lepp", "Kask"],
	},
	"caucaso": {
		"first": ["Giorgi", "Levan", "Davit", "Nika", "Zurab", "Vazha", "Aram", "Narek",
			"Gor", "Tigran", "Rashad", "Elvin", "Elnur", "Tural", "Anar"],
		"last": ["Beridze", "Kapanadze", "Tsereteli", "Mamedov", "Hakobyan", "Sargsyan",
			"Petrosyan", "Aliyev", "Huseynov", "Gurbanov", "Kvaratskhelia", "Lomidze", "Amiryan", "Mkrtchyan", "Ismayilov"],
	},
	"turco": {
		"first": ["Mehmet", "Mustafa", "Emre", "Burak", "Cem", "Hakan", "Kaan", "Ozan",
			"Berat", "Baris", "Onur", "Serkan", "Yusuf", "Ege", "Furkan"],
		"last": ["Yıldız", "Yılmaz", "Kaya", "Demir", "Şahin", "Çelik", "Aydın", "Öztürk",
			"Arslan", "Doğan", "Kılıç", "Aslan", "Çetin", "Koç", "Kurt"],
	},
	"arabe": {
		"first": ["Ahmed", "Mohamed", "Youssef", "Omar", "Karim", "Khalid", "Hassan",
			"Tariq", "Amine", "Bilal", "Zakaria", "Rachid", "Anas", "Walid", "Sami"],
		"last": ["El-Sayed", "Hassan", "Ibrahim", "Farouk", "Mansour", "Haddad", "Khalil",
			"Alaoui", "Benali", "Cherif", "Saidi", "Bouzid", "Zaidi", "Chahine", "Nasser"],
	},
	"persa": {
		"first": ["Reza", "Amir", "Hossein", "Ali", "Farhad", "Kaveh", "Arash", "Behrouz",
			"Saeed", "Navid", "Bahram", "Sohrab", "Kian", "Omid", "Payam"],
		"last": ["Hosseini", "Karimi", "Rezaei", "Ahmadi", "Moradi", "Ebrahimi", "Ghorbani",
			"Rostami", "Jafari", "Mousavi", "Sadeghi", "Nasseri", "Fadavi", "Bagheri", "Zarei"],
	},
	"hebreo": {
		"first": ["Itay", "Omer", "Eran", "Tomer", "Yossi", "Dor", "Nadav", "Idan",
			"Liel", "Gil", "Amit", "Roy", "Ben", "Shay", "Eden"],
		"last": ["Cohen", "Levi", "Mizrahi", "Peretz", "Biton", "Azulay", "Dahan",
			"Malka", "Avraham", "Bracha", "Katz", "Shapira", "Golan", "Barak", "Amar"],
	},
	"asia_central": {
		"first": ["Nurlan", "Timur", "Aidos", "Bekzat", "Erlan", "Marat", "Ruslan",
			"Askar", "Farrukh", "Sardor", "Jasur", "Otabek", "Bayar", "Batbold", "Munkh"],
		"last": ["Nazarov", "Yusupov", "Karimov", "Rashidov", "Abdullaev", "Ismailov",
			"Bekov", "Sultanov", "Toktogulov", "Amanov", "Baatar", "Dorj", "Tuvshin", "Sarsenov", "Zhaksybekov"],
	},
	"africa_oeste_a": {
		"first": ["Chidi", "Emeka", "Ifeanyi", "Kwame", "Kofi", "Kwesi", "Femi", "Tunde",
			"Yaw", "Sani", "Musa", "Bashir", "Abdul", "Chukwuemeka", "Segun"],
		"last": ["Okafor", "Okoye", "Adeyemi", "Mensah", "Owusu", "Boateng", "Danjuma",
			"Abubakar", "Nwosu", "Eze", "Bello", "Yakubu", "Amoah", "Ojo", "Afolabi"],
	},
	"africa_oeste_f": {
		"first": ["Mamadou", "Ibrahima", "Cheikh", "Moussa", "Amadou", "Souleymane", "Aliou",
			"Boubacar", "Alassane", "Sidiki", "Yacine", "Idrissa", "Fode", "Lassana", "Oumar"],
		"last": ["Diallo", "Diop", "Ndiaye", "Sow", "Traoré", "Keita", "Camara", "Sylla",
			"Coulibaly", "Cissé", "Kaboré", "Toure", "Sanogo", "Konaté", "Fofana"],
	},
	"africa_este": {
		"first": ["Juma", "Baraka", "Amani", "Hassan", "Emmanuel", "Wycliffe", "Victor",
			"Dennis", "Brian", "Patrick", "Eric", "Joseph", "Innocent", "Frank", "Michael"],
		"last": ["Otieno", "Wanjiru", "Kamau", "Mwangi", "Njoroge", "Kiprotich", "Mutua",
			"Ochieng", "Habimana", "Nsengimana", "Bekele", "Tesfaye", "Girma", "Mengistu", "Haile"],
	},
	"africa_sur": {
		"first": ["Sipho", "Themba", "Lucky", "Bongani", "Thabo", "Tendai", "Kudakwashe",
			"Given", "Blessing", "Percy", "Innocent", "Farai", "Gift", "Wisdom", "Lovemore"],
		"last": ["Ndlovu", "Dlamini", "Khumalo", "Mokoena", "Sithole", "Nkosi", "Moyo",
			"Chikwanha", "Mabika", "Banda", "Phiri", "Zulu", "Mahlangu", "Tshabalala", "Radebe"],
	},
	"asia_sur": {
		"first": ["Rahul", "Arjun", "Vikram", "Rohan", "Aakash", "Sunil", "Rajesh",
			"Faisal", "Imran", "Tanvir", "Shakib", "Kamal", "Sanjay", "Deepak", "Anil"],
		"last": ["Sharma", "Kumar", "Singh", "Patel", "Gupta", "Rahman", "Hossain",
			"Ahmed", "Khan", "Islam", "Perera", "Fernando", "Jayasuriya", "Bhandari", "Thapa"],
	},
	"chino": {
		"first": ["Wei", "Jun", "Hao", "Lei", "Yang", "Feng", "Bo", "Jian", "Tao", "Peng",
			"Chao", "Kai", "Long", "Ming", "Xin"],
		"last": ["Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao",
			"Wu", "Zhou", "Xu", "Sun", "Ma", "Zhu", "Hu"],
	},
	"japones": {
		"first": ["Haruto", "Yuto", "Sota", "Ren", "Kaito", "Sho", "Yuki", "Daiki",
			"Riku", "Ryo", "Kenta", "Takumi", "Hiroshi", "Naoki", "Shun"],
		"last": ["Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto",
			"Nakamura", "Kobayashi", "Saito", "Kato", "Yoshida", "Yamada", "Sasaki", "Inoue"],
	},
	"coreano": {
		"first": ["Min-jun", "Seo-jun", "Do-yun", "Ji-ho", "Joon-ho", "Hyun-woo", "Jun-seo",
			"Tae-yang", "Sung-min", "Jae-won", "Dong-hyun", "Kyung-soo", "Woo-jin", "Yong-gi", "Hyun-jin"],
		"last": ["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon",
			"Jang", "Lim", "Han", "Oh", "Seo", "Shin", "Kwon"],
	},
	"vietnamita": {
		"first": ["Anh", "Minh", "Duc", "Hoang", "Nam", "Long", "Tuan", "Quang",
			"Khanh", "Phong", "Bao", "Kien", "Trung", "Hieu", "Dat"],
		"last": ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Huynh", "Phan",
			"Vu", "Vo", "Dang", "Bui", "Do", "Ho", "Ngo", "Duong"],
	},
	"filipino": {
		"first": ["Miguel", "Jose", "Angelo", "Paolo", "Marco", "Rafael", "Gabriel",
			"Enzo", "Carlo", "Nathaniel", "Josiah", "Kian", "Vince", "Renz", "Jerome"],
		"last": ["Santos", "Reyes", "Cruz", "Bautista", "Ocampo", "Garcia", "Mendoza",
			"Torres", "Ramos", "Flores", "Villanueva", "Del Rosario", "Aquino", "Castillo", "Manalo"],
	},
	"sudeste_asia": {
		"first": ["Somchai", "Chan", "Kiet", "Sok", "Vann", "Thong", "Aung", "Min",
			"Kyaw", "Phone", "Rithy", "Sovan", "Bounmy", "Vong", "Kham"],
		"last": ["Srisai", "Chanthavong", "Suk", "Vongsa", "Sok", "Heng", "Phan",
			"Aung", "Naing", "Win", "Htun", "Soe", "Thura", "Lwin", "Chit"],
	},
	"malayo": {
		"first": ["Ahmad", "Muhammad", "Amir", "Farid", "Rizal", "Hakim", "Zulkifli",
			"Azman", "Firdaus", "Iskandar", "Aziz", "Fadli", "Yusof", "Hafiz", "Adi"],
		"last": ["Rahman", "Ismail", "Yusuf", "Hassan", "Aziz", "Wibowo", "Santoso",
			"Kurniawan", "Setiawan", "Susanto", "bin Ali", "bin Hamid", "Nasution", "Siregar", "Wijaya"],
	},
	"pacifico": {
		"first": ["Sione", "Semisi", "Viliami", "Etuate", "Josefa", "Ratu", "Waisale",
			"Kalati", "Tevita", "Fetu", "Malakai", "Api", "Manu", "Tanielu", "Vili"],
		"last": ["Tuilagi", "Fifita", "Havili", "Naiqama", "Waqa", "Rabuka", "Cakobau",
			"Tupou", "Fifi", "Latu", "Havea", "Tuita", "Katoa", "Moala", "Tuvale"],
	},
	"caribe_a": {
		"first": ["Marlon", "Ricardo", "Andre", "Kemar", "Shamar", "Devon", "Dwayne",
			"Kevin", "Jermaine", "Tyrone", "Nyron", "Adrian", "Cordell", "Rohan", "Akeem"],
		"last": ["Campbell", "Brown", "Williams", "Thomas", "Clarke", "Grant", "Robinson",
			"Anderson", "Bailey", "Edwards", "Henry", "James", "Morris", "Richards", "Wright"],
	},
	"haiti": {
		"first": ["Jean", "Wilner", "Jeanty", "Fabrice", "Wilkens", "Herold", "Sony",
			"Duckens", "Frantzdy", "Kervens", "Fenelon", "Judelin", "Peterson", "Rolph", "Djeny"],
		"last": ["Pierre", "Joseph", "Louis", "Jean-Baptiste", "Charles", "Alexis",
			"François", "Etienne", "Dorval", "Saint-Vil", "Delva", "Auguste", "Fils-Aimé", "Sanon", "Toussaint"],
	},
	"usa": {
		"first": ["Jordan", "Tyler", "Brandon", "Justin", "Cole", "Aaron", "Christian",
			"Ricardo", "Diego", "Marcus", "Alex", "Trevor", "Sean", "Miles", "Griffin"],
		"last": ["Johnson", "Miller", "Davis", "Wilson", "Anderson", "Thompson", "Martinez",
			"Garcia", "Rodriguez", "Lewis", "Walker", "Hall", "Allen", "Young", "King"],
	},
}

## Nombre completo determinista de un país — cae en el pool internacional
## de siempre (`fallback_first`/`fallback_last`, las mismas listas de
## WorldFactory._make_person_name) si el país no tiene región mapeada.
static func make_name(rng: RandomNumberGenerator, country: String, fallback_first: Array, fallback_last: Array) -> String:
	var region: String = String(COUNTRY_REGION.get(country, _DEFAULT_REGION))
	var pools: Dictionary = NAMES.get(region, {})
	var firsts: Array = pools.get("first", fallback_first)
	var lasts: Array = pools.get("last", fallback_last)
	var first: String = String(firsts[rng.randi() % firsts.size()])
	var last: String = String(lasts[rng.randi() % lasts.size()])
	return "%s %s" % [first, last]
