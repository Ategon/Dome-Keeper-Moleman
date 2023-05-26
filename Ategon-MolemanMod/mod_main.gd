extends Node

const MOD_DIR := "Ategon-MolemanMod/"

func _init(modLoader: ModLoader):
	var dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR
	var ext_dir = dir + "extensions/"
	
	ModLoaderMod.install_script_extension("%s/LoadoutStage.gd" % [ext_dir])
	ModLoaderMod.install_script_extension("%s/Data.gd" % [ext_dir])
	ModLoaderMod.install_script_extension("%s/Keeper.gd" % [ext_dir])
	ModLoaderMod.install_script_extension("%s/LoadoutOption.gd" % [ext_dir])
	ModLoaderMod.install_script_extension("%s/LevelStage.gd" % [ext_dir])
	ModLoaderMod.install_script_extension("%s/Audio.gd" % [ext_dir])
	
	ModLoaderMod.add_translation_from_resource("res://mods-unpacked/Ategon-MolemanMod/translations/moleman.en.translation")
