import json
import random
import uuid

# Define areas and their bounding boxes (min_lat, max_lat, min_lon, max_lon)
AREAS = {
    "North": (22.58, 22.62, 88.35, 88.39),
    "South": (22.49, 22.54, 88.34, 88.38),
    "Salt Lake": (22.56, 22.60, 88.40, 88.43),
    "Iconic": (22.55, 22.59, 88.35, 88.38),
    "Bonedi": (22.57, 22.61, 88.35, 88.37),
}

def random_coord(bbox):
    lat = random.uniform(bbox[0], bbox[1])
    lon = random.uniform(bbox[2], bbox[3])
    return lat, lon

categories = {
    "Bonedi": [
        "Srimani Barir Durga Pujo", "Hathkhola Dutta Barir Durga Pujo", "Sovabazar Rajbarir Durga Pujo",
        "Roychoudhury Barir Durga Pujo", "Khelat Ghose er Durga Pujo", "Rani Rashmoni er Durga Pujo",
        "RAMDULAL NIBAS er Durga Pujo", "Baghbazar Haldar Bari er Pujo"
    ],
    "North": [
        "Sealdah Railway Athletic Club", "College Square Sarbojonin Durgotsab Committee", "Md. Ali Park (Youth Association)",
        "Santosh Mitra square durga puja or Lebutala park", "Manicktala Chaltabagan Lohapatty Durga Puja", "Brindaban Matri Mandir",
        "Karbagan Sarbojonin Durga Puja", "Telenga Bagan Sarbojanin Durgotsab", "Nalin Sarkar Street Sarbojanin Durgotsab",
        "Hatibagan Sarbojanin", "Hatibagan Nabinpally Sarbojanin Durgotsav", "Sikdar Bagan Sadharan Durga Puja",
        "Kashi Bose Lane Durga Puja Committee", "Azad Hind Bag (Hedua Park Durga Puja)", "Simla Byayam Samity",
        "Jagat Mukherjee park", "Sovabazar Rajbari", "Ultadanga Yuba Brinda", "Ahiritola Sarbojanin Durgotsab",
        "Ahiritola Jubak Brinda", "Sovabazar Beniatola Sarbojanin Durgotsab Samity", "Kumartuli Park Sarbojanin Durgotsab Committee",
        "Kumartuli Sarbojanin Durgotsab", "Bagbazar Sarbojanin", "Deshbandhu Ladies Park", "Tala Barowari Durgotsab",
        "Tala Park Prattay", "Sree Bhumi Sporting Club", "Dum Dum Park, Tarun Sangha", "Dum Dum Park Sarbojanin",
        "Dum Dum Park Bharat Chakra", "Lake Town Adhibasi Brinda"
    ],
    "South": [
        "Badamtala Ashar Sangha", "66 Pally Sarbojanin Durgotsab", "Nepal Bhattacharya street Durga puja", "Chetla Agrani Club",
        "Deshapriya park", "Samaj Sebi Sangha", "Ballygunge Cultural Association Durga Puja", "Tridhara Sammilani",
        "Hindustan Park Sarbojanin Durgotsab Committee", "Singhi park Sarbojanin Durga Puja", "Ekdalia Evergreen club",
        "Falguni Sangha", "21 Pally Sarbojanin Durgotsab Samity", "Bosepukur Sitala Mandir", "Bosepukur Talbagan",
        "Rajdanga Naba Uday Sangha", "Babu bagan Club Sarbojanin Durga Puja", "Selimpur Pally Sarbojanin", "Jodhpur park",
        "95 pally Jodhpur park", "Trikon Park Durgotsab", "Pally Mangal Samity Sarbojanin", "Santoshpur lake pally",
        "Mudiali Club", "Shiv Mandir Sarbojanin Durga Utsav Samity", "Suruchi Sangha", "Hindusthan Club", "Behala Club",
        "Barisha Sarbojanin", "Raipur club", "Naktala Udayan sangha", "Maddox Square Durga puja", "11 Pally Youth Association Behala"
    ],
    "Salt Lake": [
        "FD Block", "AK Block", "AE Block", "AJ Block", "AA Block", "AB Block", "AC Block", "AD Block", "AG Block",
        "AH Block", "AL Block", "BA Block", "BB Block", "BC Block", "BD Block", "BE Block", "BG Block", "BH Block",
        "BJ Block", "BK Block", "BL Block", "CA Block", "CB Block", "CD Block", "CE Block", "LABONY ESTATE", "JC Block",
        "IB Block", "IA Block", "HB Block", "HA Block", "GD Block", "GC Block", "FE Block", "FC Block", "EE Block",
        "EC Market", "DL Block", "DB Block", "DA Block", "CJ Block", "CG Block"
    ],
    "Iconic": [
        "Ahiritola", "College Square", "Anupama Housing Complex", "Dum Dum Park Tarun Sangha", "Dum Dum Park Bharat Chakra",
        "Dum Dum Tarun Dal", "Dum Dum Park Yubak Brinda", "Baghbazar Sarbojonin Durgotsab & Exhibition", "Joramandir",
        "Telengabagan", "Karbagan Sarbojanin", "Gouriberia", "Kumartuli Park", "Laketown Adhibasi Brinda",
        "Laketown Netaji Sporting Club", "Md. Ali Park", "Mitali - Kankurgachi", "Salt Lake CJ Block", "Salt Lake BJ Block",
        "Salt Lake FD Block", "Salt Lake GD Block", "Salt Lake HA Block", "Salt Lake IA Block", "Salt Lake Laboni",
        "Santosh Mitra Square", "Sealdah Railway Athletic Club", "Sovabazar Beniatola", "Sreebhumi Sporting Club",
        "Tala Barowari", "Manicktala Chaltabagan Loha Patty", "Pathuriaghata Pancher Pally", "Tala Palli", "Ghas Bagan",
        "Hatibagan Nabin Pally", "Nalin Sarkar Street Sarbojanin Durgotsab", "Hatibagan Sarbojonin", "Olabibitala Sarbojanin",
        "Yuva Brinda", "Kashi Bose Lane", "Purbachal Sarbojanin", "37 Pally", "Salt Lake AJ Block",
        "Laketown Nutan Palli Pradeep Sangha", "Rammohan Sammilani", "Durga Puja of 4 Ghosh Lane",
        "Dakshineswar Dolpere Adi Sabojonin Durgapuja", "Milangarh Sarbojanin", "Motijheel Sarbojanin", "Beliaghata Nabamilan",
        "Sandhani", "Simla Byam Samity", "United Club", "Kumartuli Preparation", "Swapnar Bagan",
        "Lalabagan Yubak Brinda - Nabankur Sangha", "Sammilita Lalabagan Sarbojanin", "Salt Lake AE Block - Part 1", "Kolkata",
        "CIT Sarbojanin", "Baghbazar Jagodharti", "Beliaghata 33 No Palli", "Belgachia Sadharan Durgatsab", "Kumartuli Sarbojanin",
        "Satadal", "Salt Lake AE Block - Part 2", "Salt Lake BE Block - Part 2", "Salt Lake CK-CL Block", "Salt Lake DL block",
        "Karunamayee G Block", "Kamardanga Sitalatala - Howrah", "Arupara Milan Sangha - Howrah", "Naba Baghbazar",
        "Bangur Avenue Protirodh Bahini", "Goabagan Sarbojanin", "Hari Ghosh Street Sarbojonin", "Jagat Mukherjee Park",
        "Baghbazar Pally", "Beadon Street Sarbojanin", "Sammilita Malapara", "Darpanarayan Tagore Street Pally Samity",
        "Haritaki Bagan", "Sovabazar Sarbojanin", "Hatkhola Gosain Para", "Laketown Vivekananda Park", "Jawpur Bayam Samiti",
        "Pragati Pally Adhibasi Brindra", "Kabiraj Bagan", "Murari Pukur Bidhan Sangha", "Salt Lake AD Block", "Salt Lake AG Block",
        "Sangrami", "Tarun Sporting Club", "Shimla Vivekananda Sporting Club", "Shurir Bagan", "Salt Lake CA Block",
        "Salt Lake BG Block", "Salt Lake AH Block", "Park Circus", "Maddox Square", "Deshapriya Park", "41 Pally", "Ajeya Sanghati",
        "Vivekananda Sporting Club", "Vivekananda Park Athletic Club", "Pally Unnayan Samity Paschim Putiary",
        "Naskarpara Pally Unnayan Samity - Haridevpur", "Barisha Club", "Barisha Janakalyan Sangha", "Sabeda Bagan", "Behala Club",
        "Debdaru Fatak", "Behala Sree Sangha", "Behala Youngmen's Association", "Behala Adarsha Pally", "Badamtala Ashar Sangha",
        "Behala Nutan Dal", "Bosepukur Talbagan", "Rajdanga Tribarna Sangha", "Bosepukur Sitala Mandir", "Singhi Park",
        "Ekdalia Evergreen Club", "Jodhpur Park", "Selimpur Pally", "Santoshpur Lake Pally", "Mudiali Club",
        "Shibmandir Sarbojanin Durgotsab", "Naktala Udayan Sangha", "Rajdanga Naba Uday Sangha", "Suruchi Sangha",
        "Tridhara Sammilani", "Pratapaditya Road Tricone Park", "Sanghasree", "25 Pally", "Mukul Sangha", "66 Palli",
        "Hindustan Park", "Adi Lake Palli", "Azadgarh", "Bharat Mata", "Golfgreen Phase 2", "Santoshpur Trikon Park",
        "Yuba Sangha Club", "Netaji Nagar Sarbojanin", "Netaji Jatiya Sebadal", "New Alipore Children's Park",
        "Pally Mangal Samity", "Poddar Nagar Park", "Chakraberia Sarbojanin", "Babubagan Club", "Barisha Tarun Tirtha",
        "74 Pally", "Kabitirtha", "Pally Saradiya Club", "Behala 29 Palli", "Baishnabghata Patuli Upanagari",
        "Kendua Shanti Sangha - Patuli", "Falguni Sangha", "Chetla Agrani Club", "Chelta Sarbasadharaner Club",
        "Selimpur Naskarpara", "Bengal United Club", "Chandranath Chatterjee Street", "Greenwood Nook", "Sebak Sangha",
        "Dilip Smriti Sangha", "Lake Youth Corner", "Ekush Pally Sarbojanin Durgotsab", "Acharya Prafulla Sangha - Behala",
        "Adi Ballygunge", "Ballygunge Cultural Association", "Barisha Player's Corner", "Barisha Sabuj Sathi Club",
        "Barisha Tapoban", "Behala Arcadia Sarbojanin", "Durgabari", "Ganbani Sangha", "Samaj Sebi Sangha",
        "Sodepur Pragati Sangha (Haridevpur)", "Santoshpur Sonar Tori Durgatsav", "Abasar Sarbojonin", "Goal Math",
        "Barisha Netaji Sangha", "Behala Buroshibtala Janakalyan Sangha", "Jogajatri Club", "Surya Nagar Sarbojanin",
        "Udayan Sangha", "Uttar Panchanan Gram Milan", "Golden Arrow Club", "Purbachal Shakti Sangha", "Naskarpur Sarbojanin",
        "64 Pally", "95 Pally", "Bandhab Sammilani", "The Bengal Boys Training Association", "Nepal Bhattacharjee Street",
        "Roynagar Unnayan Samity", "Shyamapally Shyama Sangha", "Garia Sreerampur Kalyan Samity", "Bhowanipur Swadhin Sangha",
        "Dakshin Phalguni Club", "Garia Pancha Durga", "Garia Sabuj Dal", "Harish Park Puja", "Jatra Suru Sangha",
        "Judge Bagan Recreation Club", "Green Avenue Sarbojanin", "Rupchand Mukherjee Lane Sarbojanin", "Santoshpur Agragami",
        "Santoshpur Bibekananda Sangha", "Lake Pally Sarbojanin", "Golfgreen Phase 1", "19 Pally", "68 Pally", "77 Palli",
        "Abasarika Club", "Bakul Bagan Sarbojanin", "Haridevpur Adarsha Samiti", "Hindustan Club", "Manoharpukur Youngs",
        "Padmapukur Youth Association", "Padmapukur Baroyari", "Park Circus - Uddipani", "Triangular Park Sarbojanin",
        "Sitalatala Kishore Sangha", "Prasanta Disha Sarbojanin", "Barisha Yubak Brinda", "Aikya Sammilani"
    ]
}

pujas = []

for cat, names in categories.items():
    # De-duplicate names
    names = list(set(names))
    bbox = AREAS[cat]
    for name in names:
        lat, lon = random_coord(bbox)
        p_type = "heritage" if cat == "Bonedi" else "mega"
        pujas.append({
            "id": str(uuid.uuid4()),
            "name": name,
            "type": p_type,
            "lat": lat,
            "lon": lon,
            "history": f"{name} is a renowned {p_type} puja."
        })

with open("pujas.json", "w") as f:
    json.dump(pujas, f, indent=2)

print(f"Generated {len(pujas)} pujas.")
