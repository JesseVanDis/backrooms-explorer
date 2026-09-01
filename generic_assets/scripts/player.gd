extends CharacterBody3D


const SPEED: float = 3.0
const JUMP_VELOCITY: float = 4.5
const FOOTSTEP_INTERVAL: float = 0.4

@onready var camera_node : Node3D = $Neck/Camera3D

var _footstep_sounds: Array[AudioStream] = []
var _footstep_timer: float = 0.0
var _audio_player: AudioStreamPlayer3D

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)

func apply_footsteps(sounds: Array[AudioStream]) -> void:
	_footstep_sounds = sounds

func _play_footstep() -> void:
	if _footstep_sounds.is_empty():
		return
	_audio_player.stream = _footstep_sounds.pick_random()
	_audio_player.pitch_scale = randf_range(0.9, 1.3)
	_audio_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * 0.01)
			camera_node.rotate_x(-event.relative.y * 0.01)
			camera_node.rotation.x = clamp(camera_node.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	_handle_footsteps(delta)

func _handle_footsteps(delta: float) -> void:
	if is_on_floor() and velocity.length() > 0.1:
		_footstep_timer += delta
		if _footstep_timer >= FOOTSTEP_INTERVAL:
			_play_footstep()
			_footstep_timer = 0.0
	else:
		_footstep_timer = FOOTSTEP_INTERVAL # Play footstep immediately when starting to move
