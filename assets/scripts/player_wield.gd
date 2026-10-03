class_name PlayerWield
extends Node


enum WieldState {NONE, DEQUIPING, EQUIPING_START, EQUIPING}

var active_wieldable: String = ""

var _wieldable_old: String = ""
var _wield_state: WieldState = WieldState.NONE
var _seconds_since_equiping_start: float = 0.0
var _wieldables: Dictionary = {}
var _player: Node3D = null
var _old_animation_time_ms: int = 0

func _init(player: Node3D) -> void:
	_player = player

func add_wieldable(unique_name: String, p_rewind_for_dequip: bool = true, p_clear_wield_when_finish: bool = false, p_additional_args: Dictionary = {}) -> void:
	_wieldables[unique_name] = WieldableData.new(_player, unique_name, p_rewind_for_dequip, p_clear_wield_when_finish, p_additional_args)

func _on_animation_action(wieldable: WieldableData, action_name: String, action_value: Variant) -> void:
	print("animation action '" + action_name + "' fired with value: '" + str(action_value) + "'")
	if action_name == "set_animation_speed":
		var value: float = action_value
		wieldable.animation_player.speed_scale = value
	

func update(dt: float) -> void:
	_seconds_since_equiping_start = _seconds_since_equiping_start + dt
	match _wield_state:
		WieldState.NONE:
			if _wieldable_old != active_wieldable:
				var old_wieldable: WieldableData = _wieldables[_wieldable_old]
				if old_wieldable.play_animation(old_wieldable.animations.dequip):
					print("Play dequip (" + str(old_wieldable.animations.dequip.from) + " " + str(old_wieldable.animations.dequip.to) + ")")
					_wield_state = WieldState.DEQUIPING
				else:
					_wield_state = WieldState.EQUIPING_START
					_seconds_since_equiping_start = 0.0
					
		WieldState.DEQUIPING:
			var old_wieldable: WieldableData = _wieldables[_wieldable_old]
			if !old_wieldable.is_playing_animation():
				_wield_state = WieldState.EQUIPING_START
				_seconds_since_equiping_start = 0.0
				
		WieldState.EQUIPING_START:		
			var new_wieldable: WieldableData = _wieldables[active_wieldable]
			if new_wieldable.play_animation(new_wieldable.animations.equip):
				_wield_state = WieldState.EQUIPING
			else:
				_wield_state = WieldState.NONE
			_wieldable_old = active_wieldable
			_old_animation_time_ms = 0
			
		WieldState.EQUIPING:
			var new_wieldable: WieldableData = _wieldables[active_wieldable]
			if !new_wieldable.is_playing_animation():
				if new_wieldable.clear_wield_when_finish:
					active_wieldable = ""
				_wield_state = WieldState.NONE
			else:
				var current_anim_time_ms: int = int(new_wieldable.animation_player.current_animation_position * 1000.0)
				for action: Action in new_wieldable.actions_at_millisecond:
					if action.trigger_time_millis > _old_animation_time_ms and action.trigger_time_millis <= current_anim_time_ms:
						_on_animation_action(new_wieldable, action.action_name, action.action_value)
				
				_old_animation_time_ms = current_anim_time_ms
	

var active_wieldable_data: WieldableData:
	get: return _wieldables.get(active_wieldable)

static func frame_index_to_time(anim: Animation, index: float) -> float:
	return index * anim.step

var seconds_since_equiping_start: float:
	get: return _seconds_since_equiping_start;

class AnimationRange:
	var from: float = 0
	var to: float = 0
	var speed: float = 0
	func _init(p_from_frame_index: float, p_to_frame_index: float, p_speed: float = 1.0) -> void:
		from = p_from_frame_index
		to = p_to_frame_index
		speed = p_speed

class Animations:
	var equip: AnimationRange = AnimationRange.new(0,0)
	var dequip: AnimationRange = AnimationRange.new(0,0)

class Action:
	var trigger_time_millis: int
	var action_name: String
	var action_value: Variant

class WieldableData:
	var animations: Animations = Animations.new()
	var animation_player: AnimationPlayer = null
	var _animation_name: String = ""
	var _rewind_for_dequip: bool = true
	var _clear_wield_when_finish: bool = false
	var _additional_args: Dictionary = {}
	var _actions: Array[Action] = []
	
	var rewind_for_dequip: bool:
		get: return _rewind_for_dequip

	var clear_wield_when_finish: bool:
		get: return _clear_wield_when_finish
	
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
	
	
	func _init(_self_node: Node3D, p_animation_name: String, p_rewind_for_dequip: bool = true, p_clear_wield_when_finish: bool = false, p_additional_args: Dictionary = {}) -> void:
		if _self_node:
			_additional_args = p_additional_args
			_rewind_for_dequip = p_rewind_for_dequip
			_clear_wield_when_finish = p_clear_wield_when_finish
			
			animation_player = UtilsNode.find_animation_player_recursive(_self_node)
			if animation_player == null:
				push_error("animation_player is null")
				return
				
			_animation_name = p_animation_name
			
			if _animation_name == "":
				animations.equip = AnimationRange.new(0,0)
				animations.dequip = AnimationRange.new(0,0)
				return

			var anim_equip: AnimationRange = p_additional_args.get("equip", null)
			var anim_dequip: AnimationRange = p_additional_args.get("dequip", null)
			
			var anim: Animation = animation_player.get_animation(_animation_name)
			if anim == null:
				push_error("Animation not found: " + _animation_name)
			var last_frame: int = int(anim.length / anim.step) #ANIMATION_FRAMES_PER_SECOND)
			
			if anim_equip == null:
				anim_equip = AnimationRange.new(0, last_frame)
			if anim_dequip == null:
				if _rewind_for_dequip:
					anim_dequip = AnimationRange.new(last_frame, 0)
				else:
					anim_dequip = AnimationRange.new(0, 0)

			animations.equip = anim_equip
			animations.dequip = anim_dequip

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
	
	func play_animation(p_range: AnimationRange) -> bool:
		if animation_player:
			if _animation_name == "":
				return false
			var anim: Animation = animation_player.get_animation(_animation_name)
			if anim == null:
				push_error("Animation not found: '" + _animation_name + "'")
			if p_range.from == p_range.to:
				return false
			if p_range.from <= p_range.to:
				animation_player.play_section(_animation_name, PlayerWield.frame_index_to_time(anim, p_range.from), PlayerWield.frame_index_to_time(anim, p_range.to), -1,  p_range.speed, false)
			else:
				animation_player.play_section(_animation_name, PlayerWield.frame_index_to_time(anim, p_range.to), PlayerWield.frame_index_to_time(anim, p_range.from), -1, -p_range.speed, true)
			return true
		return false
	
	func is_playing_animation() -> bool:
		if animation_player:
			return animation_player.is_playing()
		else:
			return false
