## [AI-DOC] Tracks AnimationTree-driven player behaviour lifecycle states, restrictions, and status-gated camera offsets
## spec: docs/ai/systems/player.md
## status: partial
## notes: general restrictions remain active through Disabling; camera offsets are limited to Enabling and Active; actions_at_millisecond remains deferred

class_name PlayerBehaviour
extends Node

enum BehaviourStatus { IDLE, ENABLING, ACTIVE, DISABLING }

#enum WieldState {NONE, DEQUIPING, EQUIPING}

# var active_behaviour: String = ""

#var _behaviour_old: String = ""
#var _wield_state: WieldState = WieldState.NONE
#var _seconds_since_equiping_start: float = 0.0
var _behaviours: Dictionary = {} # [String, Behaviour]
var _player: Node3D = null
var _active_additional_settings: AdditionalSettings = AdditionalSettings.new()
#var _old_animation_time_ms: int = 0

func _init(player: Node3D) -> void:
	_player = player

func add(unique_name: String, p_animation_tree_parameter: StringName = "", p_additional_settings: Dictionary = {}) -> void:
	_behaviours[unique_name] = Behaviour.new(_player, unique_name, p_animation_tree_parameter, p_additional_settings)
	
func activate(unique_name: String) -> void:
	var behaviour: Behaviour = _behaviours.get(unique_name)
	if behaviour == null:
		push_error("behaviour with '" + unique_name + "' does not exist. Please first call 'add' with the this name")
	else:
		behaviour.activate()

# Cancels active one-shot playback or starts a blend fade when the caller deactivates this behaviour.
func deactivate(unique_name: String) -> void:
	var behaviour: Behaviour = _behaviours.get(unique_name)
	if behaviour == null:
		push_error("behaviour with '" + unique_name + "' does not exist. Please first call 'add' with the this name")
	else:
		behaviour.deactivate()

# Lets callers detect any non-idle lifecycle state without exposing the registered behaviours dictionary.
func is_behaviour_active(unique_name: String) -> bool:
	var behaviour: Behaviour = _behaviours.get(unique_name)
	if behaviour == null:
		push_error("behaviour with '" + unique_name + "' does not exist. Please first call 'add' with the this name")
		return false
	return behaviour.is_active()

# Exposes the current AnimationTree lifecycle state for a registered behaviour.
func get_behaviour_status(unique_name: String) -> BehaviourStatus:
	var behaviour: Behaviour = _behaviours.get(unique_name)
	if behaviour == null:
		push_error("behaviour with '" + unique_name + "' does not exist. Please first call 'add' with the this name")
		return BehaviourStatus.IDLE
	return behaviour.get_status()

#func _on_animation_action(behaviour: Behaviour, action_name: String, action_value: Variant) -> void:
	#print("animation action '" + action_name + "' fired with value: '" + str(action_value) + "'")
	#if action_name == "set_animation_speed":
		#var value: float = action_value
		#behaviour.animation_player.speed_scale = value
	#

func active_arg_value(key: String, default: Variant) -> Variant:
	return _active_additional_settings.additional_settings.get(key, default)

var active_settings: AdditionalSettings:
	get: return _active_additional_settings

# Advances blend parameters and refreshes restrictions after one-shot state changes.
func update(dt: float) -> void:
	for key: String in _behaviours:
		var behaviour: Behaviour = _behaviours[key]
		behaviour.update(dt)
	refresh_active_settings()

# Keeps general restrictions through blend-out but omits camera offsets once a behaviour starts disabling.
func refresh_active_settings() -> void:
	_active_additional_settings.additional_settings = {}
	for key: String in _behaviours:
		var behaviour: Behaviour = _behaviours[key]
		var behaviour_status: BehaviourStatus = behaviour.get_status()
		if behaviour_status == BehaviourStatus.IDLE:
			continue
		for setting_name: String in behaviour.additional_settings:
			if setting_name == "player_camera_offset" and behaviour_status != BehaviourStatus.ENABLING and behaviour_status != BehaviourStatus.ACTIVE:
				continue
			_active_additional_settings.additional_settings[setting_name] = behaviour.additional_settings[setting_name]
	
	
	#_seconds_since_equiping_start = _seconds_since_equiping_start + dt
	#match _wield_state:
		#WieldState.NONE:
			#if _behaviour_old != active_behaviour:
				#var old_behaviour: Behaviour = _behaviours[_behaviour_old]
				#if old_behaviour.animations.animation_tree_parameter != "":
					#old_behaviour.deactivate_animation()
					#_wield_state = WieldState.DEQUIPING
				#else:
					#_wield_state = WieldState.EQUIPING
					#_seconds_since_equiping_start = 0.0
				#
		#WieldState.DEQUIPING:
			#var old_behaviour: Behaviour = _behaviours[_behaviour_old]
			#if !old_behaviour.is_animation_active():
				#_wield_state = WieldState.EQUIPING
				#_seconds_since_equiping_start = 0.0
				#
		#WieldState.EQUIPING:
			#var new_behaviour: Behaviour = _behaviours[active_behaviour]
			#if new_behaviour.animations.animation_tree_parameter != "":
				#new_behaviour.activate_animation()
				#_wield_state = WieldState.NONE
			#_behaviour_old = active_behaviour
			#_old_animation_time_ms = 0


#var active_behaviour_data: Behaviour:
#	get: return _behaviours.get(active_behaviour)

#static func frame_index_to_time(anim: Animation, index: float) -> float:
#	return index * anim.step

#var seconds_since_equiping_start: float:
#	get: return _seconds_since_equiping_start;

#class AnimationRange:
	#var from: float = 0
	#var to: float = 0
	#var speed: float = 0
	#func _init(p_from_frame_index: float, p_to_frame_index: float, p_speed: float = 1.0) -> void:
		#from = p_from_frame_index
		#to = p_to_frame_index
		#speed = p_speed

class Action:
	var trigger_time_millis: int
	var action_name: String
	var action_value: Variant

class AnimationSettings:
	var additional_settings: Dictionary = {}

	var activation_speed: float:
		get: return additional_settings.get("anim_activation_speed", 6.0)

	var deactivation_speed: float:
		get: return additional_settings.get("anim_deactivation_speed", 6.0)
	

class AdditionalSettings:
	var additional_settings: Dictionary = {}

	var player_max_look_freedom_degrees_h: float:
		get: return additional_settings.get("player_max_look_freedom_degrees_h", additional_settings.get("player_max_look_freedom_degrees", 360.0))
		
	var player_max_look_freedom_degrees_v: float:
		get: return additional_settings.get("player_max_look_freedom_degrees_v", additional_settings.get("player_max_look_freedom_degrees", 360.0))

	var player_movement_multiplier: float:
		get: return additional_settings.get("player_movement_multiplier", 1.0)

	var player_max_movement_speed: float:
		get: return additional_settings.get("player_max_movement_speed", 99999.0)

	var player_max_movement_speed_to_target: float:
		get: return additional_settings.get("player_max_movement_speed_to_target", 99999.0)

	var player_camera_offset: Vector3:
		get: return additional_settings.get("player_camera_offset", Vector3.ZERO)

	var player_camera_offset_speed: float:
		get: return additional_settings.get("player_camera_offset_speed", 1.0)


class Behaviour:
	var animation_tree_parameter: StringName = ""
	var _parameter_target: float = 0.0
	var animation_tree: AnimationTree = null
	var _animation_name: String = ""
	var _additional_settings: Dictionary = {}
	var _animation_settings: AnimationSettings = AnimationSettings.new()
	var _actions: Array[Action] = [] # TODO: Make this work as well
	var _is_one_shot_request: bool = false
	var _one_shot_active_parameter: StringName = ""
	var _one_shot_request_pending: bool = false
	var _one_shot_is_disabling: bool = false
	
	var additional_settings: Dictionary:
		get: return _additional_settings;

	var actions_at_millisecond: Array[Action]:
		get: return _actions
	
	
	# Resolves the AnimationTree parameters needed to drive this registered behaviour.
	func _init(_self_node: Node3D, p_animation_name: String, p_animation_tree_parameter: StringName = "", p_additional_settings: Dictionary = {}) -> void:
		_animation_settings.additional_settings = p_additional_settings
		_additional_settings = p_additional_settings
		animation_tree = UtilsNode.find_animation_tree_recursive(_self_node)
		if animation_tree == null:
			push_error("animation_tree is null")
			return
		_animation_name = p_animation_name
		if p_animation_tree_parameter != "":
			if !p_animation_tree_parameter in animation_tree:
				push_error("'" + str(animation_tree.get_path()) + "' does not contain a property at path '" + str(p_animation_tree_parameter) + "'")
			animation_tree_parameter = p_animation_tree_parameter
			_is_one_shot_request = String(p_animation_tree_parameter).ends_with("/request")
			if _is_one_shot_request:
				_one_shot_active_parameter = StringName(String(p_animation_tree_parameter).get_base_dir() + "/active")
				if not _one_shot_active_parameter in animation_tree:
					push_error("'" + str(animation_tree.get_path()) + "' does not contain the one-shot active property at path '" + str(_one_shot_active_parameter) + "'")
			
		var actions_list: Array = p_additional_settings.get("actions_at_millisecond", [])
		for action_item: Dictionary in actions_list:
			for time_ms: int in action_item:
				var action_data: Dictionary = action_item[time_ms]
				for action_name: String in action_data:
					var action := Action.new()
					action.trigger_time_millis = time_ms
					action.action_name = action_name
					action.action_value = action_data[action_name]
					_actions.append(action)
	
	# Drops the pending one-shot request flag once the tree confirms playback has begun.
	func update(dt: float) -> void:
		if animation_tree_parameter == "":
			return
		if _is_one_shot_request:
			if _one_shot_request_pending and _is_one_shot_playing():
				_one_shot_request_pending = false
			return
		
		var parameter_value: float = animation_tree[animation_tree_parameter]
		if parameter_value != _parameter_target:
			var speed: float = _animation_settings.activation_speed
			if _parameter_target == 0.0:
				speed = _animation_settings.deactivation_speed
			parameter_value = move_toward(parameter_value, _parameter_target, speed * dt)
			animation_tree[animation_tree_parameter] = parameter_value
		
	# Fires one-shot requests once, while blend parameters continue to ramp toward one.
	func activate() -> bool:
		if _is_one_shot_request:
			if _one_shot_request_pending or _is_one_shot_playing():
				return false
			_one_shot_request_pending = true
			_one_shot_is_disabling = false
			animation_tree[animation_tree_parameter] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
			return true

		if _parameter_target != 1.0:
			print("Activating animation '" + animation_tree_parameter + "'")
			if String(animation_tree_parameter).ends_with("/blend_amount"):
				_parameter_target = 1.0
				if _animation_settings.activation_speed < 0.0:
					animation_tree[animation_tree_parameter] = 1.0
			else:
				animation_tree[animation_tree_parameter] = 1
			return true
		return false

	# Aborts a playing one-shot or ramps a blend behaviour back to zero.
	func deactivate() -> bool:
		if _is_one_shot_request:
			if not _one_shot_request_pending and not _is_one_shot_playing():
				return false
			_one_shot_is_disabling = _is_one_shot_playing()
			_one_shot_request_pending = false
			animation_tree[animation_tree_parameter] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
			return true

		if _parameter_target != 0.0:
			print("De-Activating animation '" + animation_tree_parameter + "'")
			_parameter_target = 0.0
			if _animation_settings.deactivation_speed < 0.0:
				animation_tree[animation_tree_parameter] = 0.0
			return true
		return false
	
	# Reports the current lifecycle phase so restrictions and camera offsets can use different activation windows.
	func get_status() -> PlayerBehaviour.BehaviourStatus:
		if animation_tree_parameter == "":
			return PlayerBehaviour.BehaviourStatus.ACTIVE
		if _is_one_shot_request:
			var is_one_shot_playing: bool = _is_one_shot_playing()
			if is_one_shot_playing:
				_one_shot_request_pending = false
				if _one_shot_is_disabling:
					return PlayerBehaviour.BehaviourStatus.DISABLING
				return PlayerBehaviour.BehaviourStatus.ACTIVE
			if _one_shot_is_disabling:
				_one_shot_is_disabling = false
			if _one_shot_request_pending:
				if animation_tree[animation_tree_parameter] == AnimationNodeOneShot.ONE_SHOT_REQUEST_NONE:
					_one_shot_request_pending = false
				else:
					return PlayerBehaviour.BehaviourStatus.ENABLING
			return PlayerBehaviour.BehaviourStatus.IDLE
		if String(animation_tree_parameter).ends_with("/blend_amount"):
			var blend_amount: float = animation_tree[animation_tree_parameter]
			if _parameter_target > 0.0:
				if blend_amount >= 1.0:
					return PlayerBehaviour.BehaviourStatus.ACTIVE
				return PlayerBehaviour.BehaviourStatus.ENABLING
			if blend_amount > 0.0:
				return PlayerBehaviour.BehaviourStatus.DISABLING
			return PlayerBehaviour.BehaviourStatus.IDLE
		if animation_tree[animation_tree_parameter] != 0:
			return PlayerBehaviour.BehaviourStatus.ACTIVE
		return PlayerBehaviour.BehaviourStatus.IDLE

	# Keeps restrictions active through blend fades and the full one-shot playback interval.
	func is_active() -> bool:
		return get_status() != PlayerBehaviour.BehaviourStatus.IDLE

	# Reads the AnimationTree's runtime active flag instead of the transient request value.
	func _is_one_shot_playing() -> bool:
		var is_playing: bool = animation_tree[_one_shot_active_parameter]
		return is_playing
