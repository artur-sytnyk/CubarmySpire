class_name ConfirmDialog
extends CanvasLayer


signal confirmed
signal cancelled


@onready var _title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var _text_label: Label = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var _confirm_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ConfirmBtn
@onready var _cancel_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CancelBtn


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	visible = false


func show_confirm(
		p_title: String,
		p_text: String,
		on_confirm: Callable,
		on_cancel: Callable = Callable()
) -> void:
	_title_label.text = p_title
	_text_label.text = p_text
	_confirm_btn.visible = true
	_cancel_btn.visible = true

	if confirmed.is_connected(_on_confirm):
		pass  # internal wiring only, user callbacks via one-shot connect below

	# Disconnect any previous one-shot user callbacks
	for c: Dictionary in confirmed.get_connections():
		if c["callable"] != Callable(self, "_on_confirm"):
			confirmed.disconnect(c["callable"])
	for c: Dictionary in cancelled.get_connections():
		if c["callable"] != Callable(self, "_on_cancel"):
			cancelled.disconnect(c["callable"])

	confirmed.connect(on_confirm, CONNECT_ONE_SHOT)

	if on_cancel.is_valid():
		cancelled.connect(on_cancel, CONNECT_ONE_SHOT)

	show()


func show_alert(
		p_title: String,
		p_text: String,
		on_confirm: Callable = Callable()
) -> void:
	_cancel_btn.visible = false
	show_confirm(p_title, p_text, on_confirm if on_confirm.is_valid() else Callable(self, "_noop"))


func _on_confirm() -> void:
	visible = false
	confirmed.emit()


func _on_cancel() -> void:
	visible = false
	cancelled.emit()


func _noop() -> void:
	pass
