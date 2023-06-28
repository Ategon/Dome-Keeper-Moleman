extends "res://content/shared/drops/Carryable.gd"

var loaded = false
var default_sprite
var tunnel_sprite
var tunnel_mode = false
export (int) var test

var type_map = {
	"IronDrop": "iron",
	"WaterDrop": "water",
	"SandDrop": "sand",
}

func _ready():
	for type in type_map:
		if name.find(type) != -1:
			loaded = true
			default_sprite = $Sprite.texture
			tunnel_sprite = load("res://mods-unpacked/Ategon-MolemanMod/art/moleman_%s_tunnel.png" % [type_map[type]])
			break

func set_tunnel_mode(state):
	tunnel_mode = state
	
	if loaded:
		if tunnel_mode:
			$Sprite.texture = tunnel_sprite
		else:
			$Sprite.texture = default_sprite
