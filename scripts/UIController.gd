extends Spatial

onready var camera  = $freeform
onready var lbl_pos = $"hud/dbg/pos"
onready var lbl_fps = $"hud/dbg/fps"

func _ready():
	set_process(true)

func _process(delta):
	lbl_fps.text = "FPS: " + str(Engine.get_frames_per_second())
	lbl_pos.text = "Pos: " + str(camera.translation)