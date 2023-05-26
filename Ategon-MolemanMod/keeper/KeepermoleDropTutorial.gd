extends Tutorial

var oldDropCount:int

func _ready():
	splitTutorialText("level.tutorial.drop.popup_2", "Label1", "Label2")

func process_trigger(delta:float)->bool:
	return tutorialParent.getCarrySlowdown() > 0.5

func process_confirm(delta:float):
	var newDropCount = tutorialParent.carriedCarryables.size()
	if newDropCount < oldDropCount:
		confirm()
	oldDropCount = newDropCount
