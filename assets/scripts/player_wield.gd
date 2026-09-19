class_name PlayerWield
extends Node


enum WieldState {NONE, DEQUIPING, EQUIPING_START, EQUIPING}

var active_wieldable: int = 0

var _wieldable_old: int = 0
var _wield_state: WieldState = WieldState.NONE
var _wieldables: Dictionary = {}
var _player: Node3D = null

func _init(player: Node3D) -> void:
	_player = player

func add_wieldable(id: int, p_animation_name: String, rewind_for_dequip: bool = true, p_equip: AnimationRange = null, p_dequip: AnimationRange = null) -> void:
	_wieldables[id] = WieldableData.new(_player, p_animation_name, rewind_for_dequip, p_equip, p_dequip)

func update() -> void:
	match _wield_state:
		WieldState.NONE:
			if _wieldable_old != active_wieldable:
				var old_wieldable: WieldableData = _wieldables[_wieldable_old]
				if old_wieldable.play_animation(old_wieldable.animations.dequip):
					print("Play dequip (" + str(old_wieldable.animations.dequip.from) + " " + str(old_wieldable.animations.dequip.to) + ")")
					_wield_state = WieldState.DEQUIPING
				else:
					_wield_state = WieldState.EQUIPING_START
					
		WieldState.DEQUIPING:
			var old_wieldable: WieldableData = _wieldables[_wieldable_old]
			if !old_wieldable.is_playing_animation():
				_wield_state = WieldState.EQUIPING_START
				
		WieldState.EQUIPING_START:		
			var new_wieldable: WieldableData = _wieldables[active_wieldable]
			if new_wieldable.play_animation(new_wieldable.animations.equip):
				_wield_state = WieldState.EQUIPING
			else:
				_wield_state = WieldState.NONE
			_wieldable_old = active_wieldable
			
		WieldState.EQUIPING:
			var new_wieldable: WieldableData = _wieldables[active_wieldable]
			if !new_wieldable.is_playing_animation():
				_wield_state = WieldState.NONE

static func frame_index_to_time(anim: Animation, index: float) -> float:
	return index * anim.step

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

class WieldableData:
	var animations: Animations = Animations.new()
	var animation_player: AnimationPlayer = null
	var _animation_name: String = ""

	func _init(_self_node: Node3D, p_animation_name: String, rewind_for_dequip: bool = true, p_equip: AnimationRange = null, p_dequip: AnimationRange = null) -> void:
		if _self_node:
			animation_player = UtilsNode.find_animation_player_recursive(_self_node)
			if animation_player == null:
				push_error("animation_player is null")
				return
				
			_animation_name = p_animation_name
			
			if _animation_name == "":
				animations.equip = AnimationRange.new(0,0)
				animations.dequip = AnimationRange.new(0,0)
				return

			var anim_equip: AnimationRange = p_equip
			var anim_dequip: AnimationRange = p_dequip
			
			var anim: Animation = animation_player.get_animation(_animation_name)
			if anim == null:
				push_error("Animation not found: " + _animation_name)
			var last_frame: int = int(anim.length / anim.step) #ANIMATION_FRAMES_PER_SECOND)
			
			if anim_equip == null:
				anim_equip = AnimationRange.new(0, last_frame)
			if anim_dequip == null:
				if rewind_for_dequip:
					anim_dequip = AnimationRange.new(last_frame, 0)
				else:
					anim_dequip = AnimationRange.new(0, 0)

			animations.equip = anim_equip
			animations.dequip = anim_dequip
	
	func play_animation(p_range: AnimationRange) -> bool:
		if animation_player:
			var anim: Animation = animation_player.get_animation(_animation_name)
			if anim == null:
				push_error("Animation not found: " + _animation_name)
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
