extends SceneTree

func _init() -> void:
	for property in ProjectSettings.get_property_list():
		var name: String = property.name

		if not name.begins_with("debug/gdscript/warnings/"):
			continue

		var current: Variant = ProjectSettings.get_setting(name)

		print("%s=%s" % [
			name.trim_prefix("debug/"),
			current
		])

	quit()
