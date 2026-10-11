## [AI-DOC] Headless SceneTree script that prints every configured GDScript warning project setting and then quits
## spec: docs/ai/systems/tooling.md
## status: implemented
## notes: used by tools/static_check.sh to read the project's warning configuration

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
