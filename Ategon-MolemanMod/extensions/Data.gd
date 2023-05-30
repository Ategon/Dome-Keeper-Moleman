extends "res://systems/data/Data.gd"

var upgrades_mole = {}
var gadgets_mole = {}

func keeperScene(keeperId:String):
	if keeperId == "keepermole":
		return load("res://mods-unpacked/Ategon-MolemanMod/keeper/" + .startCaptialized(keeperId) + ".tscn")
	return .keeperScene(keeperId)

func _ready():
	var f = File.new()
	var err = f.open("res://mods-unpacked/Ategon-MolemanMod/yaml/upgrades.yaml", File.READ)
	if err == OK:
		var currentKey
		var currentData
		var propertyChanges
		print("opened")
		while f.get_position() < f.get_len():
			print("aaa")
			var line:String = f.get_line()
			print(line)
			if line.strip_edges().length() > 1:

				if line.begins_with(" "):

					if propertyChanges != null:
						line = line.strip_edges()
						if line.begins_with("-"):
							var value = line.substr(1, line.length() - 1)
							var change = PropertyChange.new(value)
							propertyChanges.append(change)
							continue
						else :

							propertyChanges = null

					var split = line.split(":")
					var key = split[0].strip_edges().to_lower()
					var value = split[1].strip_edges()
					if key == "propertychanges" or key == "repeatable":
						propertyChanges = []
						currentData[key] = propertyChanges
					elif value.begins_with("["):
						value = value.replace(" ", "")
						var a = []
						var values = value.substr(1, value.length() - 2).to_lower()
						for val in values.split(","):
							a.append(str2var(val))
						currentData[key] = a

					else :
						currentData[key] = str2var(value)
				else :

					var key = line.substr(0, line.find(":")).to_lower()
					if currentKey:
						storeUpgradeDataMole(currentKey, currentData)
					currentKey = key
					currentData = {}
			else :
				if currentKey:
					storeUpgradeDataMole(currentKey, currentData)
					currentKey = null
					currentData = null
	else :
		Logger.error("failed to open upgrades2.yaml. Error: " + str(err))
		get_tree().quit()
	f.close()
	
	print(gadgets)
	print(gadgets_mole)
	
	for gk in gadgets_mole:
		gadgets_mole[gk]["id"] = gk
		gadgets_mole[gk]["tier"] = 0
		upgrades_mole[gk] = gadgets_mole[gk]

	for uk in upgrades_mole.keys().duplicate():
		var unknownPredecessor: = ""
		var upgradeData = upgrades_mole[uk]
		upgradeData["id"] = uk
		if upgradeData.has("predecessors"):
			for techId in upgradeData.get("predecessors"):
				if not upgrades_mole.has(techId):
					unknownPredecessor = techId
		if unknownPredecessor != "":
			Logger.warn("Upgrade " + uk + " has an unknown predecessor " + unknownPredecessor + ". Removing it from upgrades.")
			upgrades_mole.erase(uk)
			orderedUpgradeKeys.erase(uk)


	var openUpgrades = upgrades_mole.duplicate()
	for gk in gadgets_mole:
		openUpgrades.erase(gk)
	var currentTier: = 1
	var tieredUpgrades = []
	while true:
		for uk in openUpgrades.keys():
			var maxTier: = 0
			for techId in upgrades_mole[uk].get("predecessors", []):
				maxTier = upgrades_mole[techId].get("tier", 9999)
			if maxTier < 9999:
				tieredUpgrades.append(uk)

		if tieredUpgrades.size() == 0:
			break
		else :
			for uk in tieredUpgrades:
				upgrades_mole[uk]["tier"] = currentTier
				openUpgrades.erase(uk)

		currentTier += 1
		tieredUpgrades.clear()

	for uk in upgrades_mole.keys():
		var u = upgrades_mole[uk]
		var locks = upgrades_mole.get(uk).get("locks", [])
		for l in locks:
			var uu = upgrades_mole.get(l)
			u["tier"] = max(u["tier"], uu.get("tier", 0))

	for uk in upgrades_mole.keys():
		if upgrades_mole[uk].has("cost"):
			var costs: = {}
			var split1 = upgrades_mole[uk].get("cost").split(",")
			for costString in split1:
				var split2 = costString.split("=")
				costs[str(split2[0]).strip_edges()] = int(split2[1])
			upgrades_mole[uk]["cost"] = costs

	gadgets.merge(gadgets_mole)
	upgrades.merge(upgrades_mole)

func storeUpgradeDataMole(key:String, currentData:Dictionary):
	if currentData.has("predecessors"):
		upgrades_mole[key] = currentData
		orderedUpgradeKeys.append(key)
	elif currentData.has("rating"):
		worldModifiers[key] = currentData
	else :
		gadgets_mole[key] = currentData
		orderedUpgradeKeys.append(key)
