class_name ClearButton
extends Button
const ChromeIcons := preload("res://scripts/ChromeIcons.gd")
## Shared clear / advance control. Icon-primary for pre-readers; VO still speaks
## the full coaching line when tapped.
##   READ_ALL       — turtle + book (read slowly)
##   NEXT_SENTENCE  — chevron (next sentence)
##   NEXT_PAGE      — chevron (next page)
##   NEXT_WORD      — chevron (next word)

signal context_pressed(ctx: int)

enum Context { READ_ALL, NEXT_SENTENCE, NEXT_PAGE, NEXT_WORD }

var context: int = Context.READ_ALL
var lang: String = "en"

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(120, 72)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	refresh()

func set_context(ctx: int, language: String = "en") -> void:
	context = ctx
	lang = language
	refresh()

func refresh() -> void:
	match context:
		Context.NEXT_SENTENCE, Context.NEXT_PAGE, Context.NEXT_WORD:
			LangTheme.style_primary(self)
			ChromeIcons.apply_button(self, "next", 56)
		_:
			LangTheme.style_secondary(self)
			ChromeIcons.apply_button(self, "read_slowly", 56)

func _on_pressed() -> void:
	context_pressed.emit(context)

func _vo_for_context() -> String:
	match context:
		Context.NEXT_SENTENCE:
			return LangVo.line("next_sentence", lang)
		Context.NEXT_PAGE:
			return LangVo.line("next_page", lang)
		Context.NEXT_WORD:
			return LangVo.line("next_word", lang)
		_:
			return LangVo.line("read_all", lang)

static func vo_lines() -> Array:
	return [
		LangVo.line("read_all", "en"),
		LangVo.line("read_all", "es"),
		LangVo.line("next_sentence", "en"),
		LangVo.line("next_sentence", "es"),
		LangVo.line("next_page", "en"),
		LangVo.line("next_page", "es"),
		LangVo.line("next_word", "en"),
		LangVo.line("next_word", "es"),
	]
