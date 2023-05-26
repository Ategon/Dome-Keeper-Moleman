extends "res://stages/loadout/LoadoutStage.gd"

func beforeStart():
	GameWorld.unlockElement("keepermole")
	
	.beforeStart()

func _on_KeeperButton_pressed():
	$CanvasLayer / ChoicePopup.addOptions("keeper", ["keeper1", "keeper2", "keepermole"], GameWorld.loadoutStageConfig.keeperId, [])
	buttonToFocusOnChoicesClosed = find_node("KeeperButton")
	openChoices()

func setSkin(id:String):
	print(id)
