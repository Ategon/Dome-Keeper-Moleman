extends "res://stages/level/LevelStage.gd"

func startKeeperInput():
	var id = Level.keeper.techId.capitalize().replace(" ", "")
	print(id)
	if id != "Keepermole":
		.startKeeperInput()
		return
	
	keeperInputProcessor = load("res://mods-unpacked/Ategon-MolemanMod/keeper/InputProcessor.gd").new()
	keeperInputProcessor.keeper = Level.keeper
	keeperInputProcessor.integrate(self)
	Level.tutorials.activate()
	
	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		var popup = preload("res://stages/level/AbandonedPopup.tscn").instance()
		popup.overlay = find_node("Overlay")
		$Canvas.add_child(popup)
		
		var ei = preload("res://content/keeper/StationAbandonedInputProcessor.gd").new()
		ei.connect("no_inputs", popup, "fadeIn")
		ei.connect("got_input", popup, "fadeOut")
		ei.integrate(self)
