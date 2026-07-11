class_name BattleResultsOverlay
extends CanvasLayer

signal skip_pressed
signal watch_pressed

@onready var _victory_panel: PanelContainer = $VictoryPanel
@onready var _victory_label: Label = $VictoryPanel/MarginContainer/VBox/VictoryLabel
@onready var _skip_button: Button = $VictoryPanel/MarginContainer/VBox/ButtonRow/SkipButton
@onready var _watch_button: Button = $VictoryPanel/MarginContainer/VBox/ButtonRow/WatchButton
@onready var _results_panel: PanelContainer = $ResultsPanel
@onready var _results_label: Label = $ResultsPanel/MarginContainer/VBox/ResultsLabel
@onready var _summary_label: Label = $ResultsPanel/MarginContainer/VBox/SummaryLabel


func _ready() -> void:
	_victory_panel.visible = false
	_results_panel.visible = false
	_skip_button.pressed.connect(_on_skip_pressed)
	_watch_button.pressed.connect(_on_watch_pressed)


func show_victory(team_id: String) -> void:
	_victory_label.text = "VICTORY — %s" % team_id.to_upper()
	_victory_panel.visible = true
	_results_panel.visible = false


func show_results(rows: Array[Dictionary], summary_text: String) -> void:
	_victory_panel.visible = false
	_results_panel.visible = true

	var lines: PackedStringArray = PackedStringArray()
	lines.append("Unit          Side   State       Kills")
	lines.append("------------------------------------------")
	for row in rows:
		var star := "★ " if row.get("top", false) else "  "
		lines.append(
			"%s%-12s %-6s %-11s %d"
			% [
				star,
				row.get("name", ""),
				row.get("side", ""),
				row.get("state", ""),
				row.get("kills", 0),
			]
		)

	_results_label.text = "\n".join(lines)
	_summary_label.text = summary_text


func hide_all() -> void:
	_victory_panel.visible = false
	_results_panel.visible = false


func _on_skip_pressed() -> void:
	skip_pressed.emit()


func _on_watch_pressed() -> void:
	_victory_panel.visible = false
	watch_pressed.emit()
