extends Tutorial

func _ready():
	splitTutorialText("level.tutorial.pickup.popup_1", "Label1", "Label2")

func process_trigger(delta:float)->bool:
	return tutorialParent.carryables.size() > 0

func process_confirm(delta:float):
	if tutorialParent.carriedCarryables.size() > 0:
		confirm()
