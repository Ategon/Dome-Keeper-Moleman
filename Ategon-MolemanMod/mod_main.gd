extends Node

const MOD_DIR := "Ategon-MolemanMod/"

func _init(modLoader: ModLoader):
	var dir = Directory.new()
	if dir.open("res://mods-unpacked/" + MOD_DIR) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name == "extensions":
					_install_extensions(modLoader)
			file_name = dir.get_next()
	
	ModLoaderMod.add_translation("res://mods-unpacked/Ategon-MolemanMod/translations/moleman.en.translation")

func _install_extensions(modLoader):
	var dir_name = "res://mods-unpacked/" + MOD_DIR + "extensions/"
	var dir = Directory.new()
	
	if dir.open(dir_name) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				ModLoaderMod.install_script_extension("%s%s" % [dir_name, file_name])
			file_name = dir.get_next()
