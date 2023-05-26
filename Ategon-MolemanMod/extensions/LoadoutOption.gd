extends "res://stages/loadout/LoadoutOption.gd"

func init(id:String, unlockable:bool = true, isPet: = false, isSkin: = false):
	if(id != "keepermole"):
		.init(id, unlockable, isPet, isSkin)
		return
	
	self.id = id
	find_node("IconRect").texture = load("res://mods-unpacked/Ategon-MolemanMod/icons/loadout_" + id + ".png")
	titleText = tr("upgrades." + id + ".title")
	find_node("TitleLabel").text = titleText
	
	if not unlockable:
		find_node("DescriptionLabel").bbcode_text = tr("loadout.choices.comingsoon")
	elif disabled:
		find_node("DescriptionLabel").bbcode_text = tr("loadout.choices.locked")
	else :
		find_node("DescriptionLabel").bbcode_text = tr("upgrades." + id + ".desc")
	
	if disabled:
		set("custom_styles/panel", preload("res://gui/buttons/button_disabled.tres"))
	
	$SelectedPanel.visible = false
