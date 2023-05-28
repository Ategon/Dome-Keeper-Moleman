extends Node

const MOD_DIR := "Ategon-MolemanMod/"

func _init(modLoader: ModLoader):
	var dir = Directory.new()
	if dir.open(ModLoaderMod.get_unpacked_dir() + MOD_DIR) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name == "extensions":
					_install_extensions()
			file_name = dir.get_next()
	
	ModLoaderMod.add_translation_from_resource("res://mods-unpacked/Ategon-MolemanMod/translations/moleman.en.translation")

func _install_extensions():
	var dir_name = ModLoaderMod.get_unpacked_dir() + MOD_DIR + "extensions/"
	var dir = Directory.new()
	
	if dir.open(dir_name) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				ModLoaderMod.install_script_extension("%s/%s" % [dir_name, file_name])
			file_name = dir.get_next()
