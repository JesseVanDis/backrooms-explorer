## [AI-DOC] Area3D that fires once when its target enters, leaves or is looked at, playing a sound or queueing player voice lines
## spec: docs/ai/systems/interaction.md
## status: implemented

extends Area3D
class_name Trigger

enum Mode {
	None,
	PlayerVoice_Replace,
	PlayerVoice_PushBack,
	PlayerVoice_PushFront,
}

enum Condition {
	OnEnter,
	OnLeave,
	WhileInside_PlayerLookAtNode,
	WhileInside_PlayerLookAtNode_DirectLineOfSight,
}


## If empty, it will use the player as default.
@export var trigger_object: Node3D = null
@export var mode: Mode = Mode.None
@export var sounds: Array[AudioStream] = []
@export var trigger_delay_ms: int = 0

## If set, it will invoke player.set_flag("_[lvl_id]_trigger_[NAME]"), where [NAME] is whatever you put here. It also means if this flag is already set, the trigger will not happen.
@export var player_flag: String

@export_group("Condition")
@export var condition: Condition = Condition.OnEnter
@export var condition_arg_node: Node3D = null

var _has_triggered: bool = false
var _audio_player: AudioStreamPlayer3D = null
var _player: Player = null
var _is_target_inside: bool = false
var _was_target_ever_inside: bool = false

func get_player() -> Player:
	if _player == null:
		_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in trigger.gd")
	return _player

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	if condition == Condition.WhileInside_PlayerLookAtNode && condition_arg_node == null:
		push_error("condition Condition.PlayerLookAtNode requires a valid condition_arg_node in trigger '" + str(get_path()) + "'")
	if condition == Condition.WhileInside_PlayerLookAtNode_DirectLineOfSight && condition_arg_node == null:
		push_error("condition Condition.WhileInside_PlayerLookAtNode_DirectLineOfSight requires a valid condition_arg_node in trigger '" + str(get_path()) + "'")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_exited(body: Node3D) -> void:
	var target_trigger: Node3D = trigger_object
	if target_trigger == null:
		target_trigger = get_player()
	if body == target_trigger:
		_is_target_inside = false

func _on_body_entered(body: Node3D) -> void:
	var target_trigger: Node3D = trigger_object
	if target_trigger == null:
		target_trigger = get_player()
	if body == target_trigger:
		_is_target_inside = true
		_was_target_ever_inside = true

var player_flag_formatted: String:
	get():
		if player_flag:
			var level_name: String = String(get_path()).split("/")[1]
			return "_" + level_name + "_trigger_" + player_flag
		return ""

func _physics_process(_delta: float) -> void:
	if _has_triggered:
		return
	
	if !player_flag.is_empty():
		if get_player().is_flag_set(player_flag_formatted):
			# was triggered elsewhere
			_has_triggered = true
			return
	
	var trigger: bool = false
	
	match condition:
		Condition.OnEnter:
			if _is_target_inside:
				trigger = true
		
		Condition.OnLeave:
			if _was_target_ever_inside && !_is_target_inside:
				trigger = true
		
		Condition.WhileInside_PlayerLookAtNode:
			if _is_target_inside:
				var camera: Camera3D = UtilsNode.find_camera_recursive(get_player())
				var to_node: Vector3 = (condition_arg_node.global_position - camera.global_position).normalized()
				var forward: Vector3 = -camera.global_basis.z
				var dot: float = forward.dot(to_node)
				if dot > 0.85: # Approximately 30 degrees
					trigger = true
		
		Condition.WhileInside_PlayerLookAtNode_DirectLineOfSight:
			if _is_target_inside:
				var camera: Camera3D = UtilsNode.find_camera_recursive(get_player())
				var to_node: Vector3 = (condition_arg_node.global_position - camera.global_position).normalized()
				var forward: Vector3 = -camera.global_basis.z
				var dot: float = forward.dot(to_node)
				if dot > 0.85: # Approximately 30 degrees
					# check if there is somethign blocking the view
					var target_area: Area3D = condition_arg_node as Area3D
					if target_area == null:
						target_area = condition_arg_node.get_parent() as Area3D
					if target_area == null:
						push_error("WhileInside_PlayerLookAtNode_DirectLineOfSight does not work on a target who is not part of an Area3D")
					else:
						var from_pos: Vector3 = camera.global_position
						var to_pos: Vector3 = condition_arg_node.global_position
						# var query := PhysicsRayQueryParameters3D.create(camera.global_position, condition_arg_node.global_position)
						
						var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
						# use global coordinates, not local to node
						var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
						query.collide_with_areas = true
						var result: Dictionary = space_state.intersect_ray(query)
						
						# query.exclude = [get_player()]
						#var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
						#print("cam pos: " + str(from_pos) + ", to pos: " + str(to_pos) + " raytrace empty: " + str(result.is_empty()))
						var has_line_of_sight: bool = (
							not result.is_empty()
							and result["collider"] == target_area
						)
						if has_line_of_sight:
							trigger = true	
	
	
	if trigger:
		_has_triggered = true
		print("Triggered '" + str(get_path()) + "'")
		if !player_flag.is_empty():
			get_player().set_flag(player_flag_formatted)
		await _trigger()


func _trigger() -> void:
	if trigger_delay_ms > 0:
		await get_tree().create_timer(trigger_delay_ms / 1000.0).timeout

	match mode:
		Mode.None:
			if sounds.size() == 0:
				pass
			elif sounds.size() == 1:
				var target_player: AudioStreamPlayer3D = _audio_player
				_audio_player.stream = sounds.front()
				target_player.play()
			else:
				push_error("Non-voice sound sequence not implemented yet.")
		
		Mode.PlayerVoice_Replace:
			get_player().replace_voice(sounds)
		
		Mode.PlayerVoice_PushBack:
			get_player().push_back_voice(sounds)
				
		Mode.PlayerVoice_PushFront:
			get_player().push_front_voice(sounds)
	
	
