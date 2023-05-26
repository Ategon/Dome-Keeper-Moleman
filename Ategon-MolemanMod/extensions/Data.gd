extends "res://systems/data/Data.gd"

func keeperScene(keeperId:String):
	if keeperId == "keepermole":
		return load("res://mods-unpacked/Ategon-MolemanMod/keeper/" + .startCaptialized(keeperId) + ".tscn")
	return .keeperScene(keeperId)

func _ready():
	var f = File.new()
	f.open("res://properties.yaml", File.READ)
	var currentId
	while not f.eof_reached():
		var line = f.get_line()
		var parts = line.split(":", false)
		match parts.size():
			0:
				currentId = null
			1:
				currentId = parts[0].strip_edges().to_lower()
			2:
				var key = currentId + "." + parts[0].strip_edges().to_lower()
				if parts[0].to_lower().find("template") != - 1:
					templates[key.substr(0, key.length() - 8)] = parts[1].strip_edges()
				elif parts[1].find(",") != - 1:
					var values: = []
					for v in parts[1].split(","):
						values.append(str2var(v.strip_edges()))

					gameProperties[key] = values
				else :
					gameProperties[key] = str2var(parts[1].strip_edges())
	f.close()
	
	
	upgrades = {}
	gadgets = {}
	f = File.new()
	var err = f.open("res://upgrades.yaml", File.READ)
	if err == OK:
		var currentKey
		var currentData
		var propertyChanges
		while not f.eof_reached():
			var line:String = f.get_line()
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
						storeUpgradeData(currentKey, currentData)
					currentKey = key
					currentData = {}
			else :
				if currentKey:
					storeUpgradeData(currentKey, currentData)
					currentKey = null
					currentData = null
	else :
		Logger.error("failed to open upgrades.yaml. Error: " + str(err))
		get_tree().quit()
	f.close()
	
	f = File.new()
	err = f.open("res://mods-unpacked/Ategon-MolemanMod/yaml/upgrades.yaml", File.READ)
	if err == OK:
		var currentKey
		var currentData
		var propertyChanges
		while not f.eof_reached():
			var line:String = f.get_line()
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
						storeUpgradeData(currentKey, currentData)
					currentKey = key
					currentData = {}
			else :
				if currentKey:
					storeUpgradeData(currentKey, currentData)
					currentKey = null
					currentData = null
	else :
		Logger.error("failed to open upgrades2.yaml. Error: " + str(err))
		get_tree().quit()
	f.close()
	
	
	for gk in gadgets:
		gadgets[gk]["id"] = gk
		gadgets[gk]["tier"] = 0
		upgrades[gk] = gadgets[gk]
	
	
	for uk in upgrades.keys().duplicate():
		var unknownPredecessor: = ""
		var upgradeData = upgrades[uk]
		upgradeData["id"] = uk
		if upgradeData.has("predecessors"):
			for techId in upgradeData.get("predecessors"):
				if not upgrades.has(techId):
					unknownPredecessor = techId
		if unknownPredecessor != "":
			Logger.warn("Upgrade " + uk + " has an unknown predecessor " + unknownPredecessor + ". Removing it from upgrades.")
			upgrades.erase(uk)
			orderedUpgradeKeys.erase(uk)
	
	
	var openUpgrades: = upgrades.duplicate()
	for gk in gadgets:
		openUpgrades.erase(gk)
	var currentTier: = 1
	var tieredUpgrades = []
	while true:
		for uk in openUpgrades.keys():
			var maxTier: = 0
			for techId in upgrades[uk].get("predecessors", []):
				maxTier = upgrades[techId].get("tier", 9999)
			if maxTier < 9999:
				tieredUpgrades.append(uk)
		
		if tieredUpgrades.size() == 0:
			break
		else :
			for uk in tieredUpgrades:
				upgrades[uk]["tier"] = currentTier
				openUpgrades.erase(uk)
				
		currentTier += 1
		tieredUpgrades.clear()
	
	for uk in upgrades.keys():
		var u = upgrades[uk]
		var locks = upgrades.get(uk).get("locks", [])
		for l in locks:
			var uu = upgrades.get(l)
			u["tier"] = max(u["tier"], uu.get("tier", 0))
	
	for uk in upgrades.keys():
		if upgrades[uk].has("cost"):
			var costs: = {}
			var split1 = upgrades[uk].get("cost").split(",")
			for costString in split1:
				var split2 = costString.split("=")
				costs[str(split2[0]).strip_edges()] = int(split2[1])
			upgrades[uk]["cost"] = costs
	pass
