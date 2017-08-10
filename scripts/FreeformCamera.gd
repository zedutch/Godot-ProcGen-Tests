extends Spatial

export(float) var speed = 0.5
export(float) var mouse_sensitivity = 0.01

var mouse_captured = false

func _ready():
	set_process_input(true)
	set_process(true)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if mouse_captured:
			capture_mouse(false)
		else:
			get_tree().quit()
	
	# Handle movement
	var trans = Vector3()
	var globtrans = Vector3()
	
	if Input.is_action_pressed("cam_forward"):
		trans.z = -1
	if Input.is_action_pressed("cam_back"):
		trans.z = 1
	if Input.is_action_pressed("cam_left"):
		trans.x = -1
	if Input.is_action_pressed("cam_right"):
		trans.x = 1
	if Input.is_action_pressed("cam_up"):
		globtrans.y = 1
	if Input.is_action_pressed("cam_down"):
		globtrans.y = -1
	
	translate(trans.normalized() * speed)
	global_translate(globtrans.normalized() * speed)

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		var yaw   = -event.get_relative().x * mouse_sensitivity
		var pitch = -event.get_relative().y * mouse_sensitivity
		rotate_y(yaw)
		rotate(get_global_transform().basis.x.normalized(), pitch)
		
	elif event is InputEventMouseButton and event.get_button_index() == BUTTON_LEFT:
		capture_mouse(true)

func capture_mouse(enable):
	if enable:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = enable