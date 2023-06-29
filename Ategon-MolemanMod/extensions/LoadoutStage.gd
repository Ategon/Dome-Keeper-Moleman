extends "res://stages/loadout/LoadoutStage.gd"

func beforeStart():
	GameWorld.unlockElement("keepermole")
	
	.beforeStart()

func _on_KeeperButton_pressed():
	$CanvasLayer / ChoicePopup.addOptions("keeper", ["keeper1", "keeper2", "keepermole"], GameWorld.loadoutStageConfig.keeperId, [])
	buttonToFocusOnChoicesClosed = find_node("KeeperButton")
	openChoices()

func _process(delta):
	if GameWorld.paused:
		return 
		
	if not GameWorld.loadoutStageConfig.keeperId == "keepermole":
		._process(delta)
		
	processKeepermole(delta)
	

var keeperMoveWait = 0

func moveKeeper(posNode)->bool:
	var d = posNode.position - keeper.position
	if d.length() < 16.0:
		keeper.moveDirectionInput *= 0
		return true
	else :
		keeper.moveDirectionInput = (d * 0.1).limit_length(1.0)
		return false

func moveKeeper2(posNode):
	var d = posNode.position - keeper.position
	keeper.moveDirectionInput = (d * 0.1).limit_length(1.0)
	return false

func processKeepermole(delta):
	if keeperWait > 0.0:
		keeperWait -= delta
	elif keeperMoveWait > 0.0:
		keeperMoveWait -= delta
		moveKeeper2($KeeperPosition2)
		keeper.pickupHold()
	else :
		match keeperPhase:
			0:
				keeperWait = 1.0
				keeperPhase += 1
			1:
				if moveKeeper($KeeperPosition2):
					keeperMoveWait = 0.4
					keeperPhase += 1
				else:
					keeper.pickupHold()
			2:
				if moveKeeper($KeeperPosition3):
					keeperWait = 5.0
					keeperPhase += 1
					keeper.pickupHoldStopped()
			3:
				keeper.pickupHit()
				keeperWait = 0.2
				keeperPhase += 1
			4:
				keeper.pickupHit()
				keeperWait = 0.2
				keeperPhase += 1
			5:
				keeper.pickupHit()
				keeperWait = 1.0
				keeperPhase += 1
			6:
				if moveKeeper($KeeperPosition4):
					keeperWait = 1.0
					keeperPhase += 1
			7:
				keeper.dropHit()
				keeperWait = 0.2
				keeperPhase += 1
			8:
				keeper.dropHit()
				keeperWait = 0.2
				keeperPhase += 1
			9:
				keeper.dropHit()
				keeperWait = 1.0
				keeperPhase += 1
			10:
				resetMap()
				keeperWait = 1.0 + randf() * 1.0
				keeperPhase = 1
				$Tween.interpolate_callback(self, 1.0, "clearResources")
				$Tween.start()
