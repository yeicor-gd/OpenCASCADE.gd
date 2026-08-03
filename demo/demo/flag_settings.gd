@tool
extends PanelContainer
## Inspector-like panel for the flag demo: every exported parameter of the
## `Flag` node becomes an editable control (read from its property list, so new
## exports and tool buttons show up automatically, e.g. Rebuild and Step).

@export var flag: Flag

var _content: VBoxContainer
var _controls := {}
var _sync := false


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_content)

	_build_form()


func _process(_delta: float) -> void:
	if _sync or flag == null:
		return
	_sync = true
	for prop in _controls:
		var control: Control = _controls[prop]
		var value = flag.get(prop)
		if control is SpinBox:
			control.set_value_no_signal(value)
		elif control is CheckButton:
			control.set_pressed_no_signal(value)
	_sync = false


func _build_form() -> void:
	if flag == null:
		_add_label("Assign a Flag node to edit its parameters.")
		return

	var items: Array = []
	for p in flag.get_property_list():
		var usage: int = p.get("usage", 0)
		if usage & PROPERTY_USAGE_GROUP:
			items.append({"kind": "group", "name": p["name"]})
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			items.append({
				"kind": "prop",
				"name": p["name"],
				"type": p.get("type", 0),
				"hint": p.get("hint", 0),
				"hint_string": String(p.get("hint_string", "")),
			})

	var shown_group := ""
	for item in items:
		if item["kind"] == "group":
			shown_group = item["name"]
		else:
			if shown_group != "" and shown_group != _last_group_shown:
				_add_group_header(shown_group)
				_last_group_shown = shown_group
			_add_property_row(item)


var _last_group_shown := ""


func _add_property_row(item: Dictionary) -> void:
	var prop: String = item["name"]

	if item["type"] == TYPE_CALLABLE and item["hint"] == PROPERTY_HINT_TOOL_BUTTON:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = item["hint_string"]
		button.pressed.connect(func() -> void: (flag.get(prop) as Callable).call())
		_controls[prop] = button
		_content.add_child(button)
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = prop.trim_prefix("_")
	label.custom_minimum_size.x = 150
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	var control: Control
	match item["type"]:
		TYPE_BOOL:
			var check := CheckButton.new()
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.toggled.connect(func(on: bool) -> void: _set_flag(prop, on))
			control = check
		TYPE_INT:
			var spin := SpinBox.new()
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.min_value = -1.0e6
			spin.max_value = 1.0e6
			spin.step = 1.0
			spin.rounded = true
			spin.value = flag.get(prop)
			spin.value_changed.connect(func(value: float) -> void: _set_flag(prop, int(value)))
			control = spin
		TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.min_value = -1.0e6
			spin.max_value = 1.0e6
			spin.step = 0.01
			spin.value = flag.get(prop)
			spin.value_changed.connect(func(value: float) -> void: _set_flag(prop, value))
			control = spin
		_:
			return

	row.add_child(control)
	_controls[prop] = control
	_content.add_child(row)


func _set_flag(prop: String, value: Variant) -> void:
	if _sync or flag == null:
		return
	flag.set(prop, value)


func _add_group_header(group: String) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = group
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	header.add_child(label)
	_content.add_child(header)
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(rule)


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
