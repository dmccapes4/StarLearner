extends CanvasLayer
## Top-left star count — Kenney yellow icon + collected/total label.

const STAR_ICON := "res://assets/ui/kenney_ui_pack/PNG/Yellow/Default/star.png"

@onready var _icon: TextureRect = $Margin/Row/Icon
@onready var _label: Label = $Margin/Row/Label

func _ready() -> void:
	layer = 10
	if ResourceLoader.exists(STAR_ICON):
		_icon.texture = load(STAR_ICON) as Texture2D
	_refresh()
	Events.star_collected.connect(_on_star_collected)

func _on_star_collected(_star_id: String) -> void:
	_refresh()

func _refresh() -> void:
	var db := StarDB.new()
	db.load_db()
	var total := db.stars_ordered.size()
	var collected := 0
	for entry in db.stars_ordered:
		if Save.has_star(str(entry.get("id", ""))):
			collected += 1
	_label.text = "%d/%d" % [collected, total]
