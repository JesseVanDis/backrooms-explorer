## [AI-DOC] State machine that equips and dequips the player's wieldables by playing animation sections and firing time-based animation actions
## spec: docs/ai/systems/player.md
## status: partial
## notes: WieldableData exposes per-wieldable look-freedom and movement-speed limits read by the player

class_name PlayerWield
extends Node


enum WieldState {NONE, DEQUIPING, EQUIPING}

var active_wieldable: String = ""

var _wieldable_old: String = ""
var _wield_state: WieldState = WieldState.NONE
var _seconds_since_equiping_start: float = 0.0
var _wieldables: Dictionary = {}
var _player: Node3D = null
var _old_animation_time_ms: int = 0

func _init(player: Node3D) -> void:
	_player = player

func add_wieldable(unique_name: String, p_animation_tree_parameter: StringName = "", p_additional_args: Dictionary = {}) -> void:
	_wieldables[unique_name] = WieldableData.new(_player, unique_name, p_animation_tree_parameter, p_additional_args)

#func _on_animation_action(wieldable: WieldableData, action_name: String, action_value: Variant) -> void:
	#print("animation action '" + action_name + "' fired with value: '" + str(action_value) + "'")
	#if action_name == "set_animation_speed":
		#var value: float = action_value
		#wieldable.animation_player.speed_scale = value
	#

func update(dt: float) -> void:
	_seconds_since_equiping_start = _seconds_since_equiping_start + dt
	match _wield_state:
		WieldState.NONE:
			if _wieldable_old != active_wieldable:
				var old_wieldable: WieldableData = _wieldables[_wieldable_old]
				if old_wieldable.animations.animation_tree_parameter != "":
					old_wieldable.deactivate_animation()
					_wield_state = WieldState.DEQUIPING
					
		WieldState.DEQUIPING:
			var old_wieldable: WieldableData = _wieldables[_wieldable_old]
			if !old_wieldable.is_animation_active():
				_wield_state = WieldState.EQUIPING
				_seconds_since_equiping_start = 0.0
				
		WieldState.EQUIPING:
			var new_wieldable: WieldableData = _wieldables[active_wieldable]
			if new_wieldable.animations.animation_tree_parameter != "":
				new_wieldable.activate_animation()
				_wield_state = WieldState.NONE
			_wieldable_old = active_wieldable
			_old_animation_time_ms = 0


var active_wieldable_data: WieldableData:
	get: return _wieldables.get(active_wieldable)

static func frame_index_to_time(anim: Animation, index: float) -> float:
	return index * anim.step

var seconds_since_equiping_start: float:
	get: return _seconds_since_equiping_start;

#class AnimationRange:
	#var from: float = 0
	#var to: float = 0
	#var speed: float = 0
	#func _init(p_from_frame_index: float, p_to_frame_index: float, p_speed: float = 1.0) -> void:
		#from = p_from_frame_index
		#to = p_to_frame_index
		#speed = p_speed

class Animations:
	var animation_tree_parameter: StringName = ""

class Action:
	var trigger_time_millis: int
	var action_name: String
	var action_value: Variant

class WieldableData:
	var animations: Animations = Animations.new()
	var animation_tree: AnimationTree = null
	var _animation_name: String = ""
	var _additional_args: Dictionary = {}
	var _actions: Array[Action] = []
	
	var max_look_freedom_degrees_h: float:
		get: return _additional_args.get("max_look_freedom_degrees_h", _additional_args.get("max_look_freedom_degrees", 360.0))
		
	var max_look_freedom_degrees_v: float:
		get: return _additional_args.get("max_look_freedom_degrees_v", _additional_args.get("max_look_freedom_degrees", 360.0))
	
	var movement_multiplier: float:
		get: return _additional_args.get("movement_multiplier", 1.0)

	var max_movement_speed: float:
		get: return _additional_args.get("max_movement_speed", 99999.0)

	var max_movement_speed_to_target: float:
		get: return _additional_args.get("max_movement_speed_to_target", 99999.0)
	
	var actions_at_millisecond: Array[Action]:
		get: return _actions
	
	
	func _init(_self_node: Node3D, p_animation_name: String, p_animation_tree_parameter: StringName = "", p_additional_args: Dictionary = {}) -> void:
		_additional_args = p_additional_args
		animation_tree = UtilsNode.find_animation_tree_recursive(_self_node)
		if animation_tree == null:
			push_error("animation_tree is null")
			return
		_animation_name = p_animation_name
		if p_animation_tree_parameter != "":
			if not animation_tree[p_animation_tree_parameter]:
				push_error("animation tree '" + str(animation_tree.get_path()) + "' does not contain the parameter '" + p_animation_tree_parameter + "'")
			animations.animation_tree_parameter = p_animation_tree_parameter
			
		var actions_list: Array = p_additional_args.get("actions_at_millisecond", [])
		for action_item: Dictionary in actions_list:
			for time_ms: int in action_item:
				var action_data: Dictionary = action_item[time_ms]
				for action_name: String in action_data:
					var action := Action.new()
					action.trigger_time_millis = time_ms
					action.action_name = action_name
					action.action_value = action_data[action_name]
					_actions.append(action)
	
	func activate_animation() -> bool:
		animation_tree[animations.animation_tree_parameter] = 1
		# animation_tree[p_animation_tree_parameter] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		return false

	func deactivate_animation() -> bool:
		animation_tree[animations.animation_tree_parameter] = 0
		return false
	
	func is_animation_active() -> bool:
		if animation_tree[animations.animation_tree_parameter] != 0:
			return true
		return false
