class_name UiStyle
extends RefCounted
## Stile fumettoso dell'interfaccia, lo stesso del sito ufotizio.com: font
## Fredoka, contorni neri spessi, ombre piene spostate in basso a destra,
## pulsanti a pillola color crema e pannelli coi verdi del sito. Il tema
## vale per tutti i Control del gioco (apply, chiamato da Platform
## all'avvio); i pannelli disegnati a mano (HUD, minimappa...) usano box,
## pill e draw_bar.

## Inchiostro dei contorni e delle ombre, crema dei pulsanti e dei testi.
const INK := Color("0d0f0e")
const CREAM := Color("f5f7f6")
const SHADOW := Color(0, 0, 0, 0.35)
## Pannelli, fondo delle barre e colore della scelta: i verdi del sito e il
## giallo dei pulsanti selezionati.
const PANEL := Color("00683f")
const SOFT := Color("134a33")
const ACCENT := Color("ffd23f")
## Fondo delle schermate a tutto schermo (comandi, opzioni, tutorial...) e
## delle velature sul gioco (pausa, inventario, negozio).
const OVERLAY := Color("0e3a28")
## Testo sui pulsanti selezionati e sui distintivi del colore della scelta.
const ACCENT_TEXT := INK
## Sfondo del menù iniziale (sfumatura radiale come sul sito) e titolo.
const BACK_LIGHT := Color("3eeea6")
const BACK := Color("23c483")
const BACK_DARK := Color("109e66")
const TITLE := CREAM
const BORDER := 4
const OUTLINE := 6
const FONT_PATH := "res://assets/fonts/fredoka_semibold.ttf"
const BOLD_PATH := "res://assets/fonts/fredoka_bold.ttf"
## Frecce della croce e pochi altri simboli che Fredoka non ha (sottoinsieme
## di Inter): nel browser non ci sono i font del sistema da cui prenderli.
const SYMBOLS_PATH := "res://assets/fonts/symbols.otf"

static var _font: Font
static var _bold: Font


static func font() -> Font:
	if _font == null:
		_font = _load_font(FONT_PATH)
	return _font


## Titoli grandi (menù iniziale).
static func bold() -> Font:
	if _bold == null:
		_bold = _load_font(BOLD_PATH)
	return _bold


static func _load_font(path: String) -> Font:
	var file := (load(path) as FontFile).duplicate() as FontFile
	var extra: Array[Font] = [load(SYMBOLS_PATH)]
	file.fallbacks = extra
	return file


## Font e tema per tutto il gioco. Il tema si fonde in quello predefinito
## di Godot, così vale anche per i Control sotto un CanvasLayer o un Node
## (HUD, pannelli, strumenti di cattura); anche ciò che si disegna con
## ThemeDB.fallback_font (HUD, minimappa...) usa Fredoka.
static func apply() -> void:
	ThemeDB.fallback_font = font()
	ThemeDB.get_default_theme().merge_with(theme())


## Riquadro con il contorno nero e l'ombra piena (shadow 0: senza ombra).
static func box(fill: Color, radius := 20, border := BORDER, shadow := 6.0, shadow_color := SHADOW) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.anti_aliasing_size = 0.8
	if shadow > 0.0:
		# Un solo pixel di sfumatura: l'ombra resta piena come nel disegno.
		style.shadow_color = shadow_color
		style.shadow_size = 1
		style.shadow_offset = Vector2(shadow, shadow)
	return style


## Pillola: riquadro con le estremità tonde (pulsanti, barre, etichette).
static func pill(fill: Color, border := 3, shadow := 0.0) -> StyleBoxFlat:
	return box(fill, 999, border, shadow, INK)


## Barra a pillola col contorno nero, piena per la frazione ratio, con un
## riflesso chiaro in alto.
static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color, back := SOFT, border := 3) -> void:
	canvas.draw_style_box(pill(back, border), rect)
	var inner := rect.grow(-border)
	var width := inner.size.x * clampf(ratio, 0.0, 1.0)
	if width < 1.0 or inner.size.y < 1.0:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(ceili(inner.size.y / 2.0))
	fill.border_color = color.lightened(0.4)
	fill.border_width_top = maxi(1, roundi(inner.size.y * 0.3))
	canvas.draw_style_box(fill, Rect2(inner.position, Vector2(width, inner.size.y)))


## Tema di tutti i Control: pulsanti crema a pillola (gialli quando sono
## selezionati), testi chiari col contorno nero, pannelli verdi.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16

	var normal := pill(CREAM, BORDER, 5.0)
	var hover := pill(CREAM.lerp(ACCENT, 0.35), BORDER, 6.0)
	var pressed := pill(ACCENT.darkened(0.12), BORDER, 2.0)
	var focus := pill(ACCENT, BORDER, 7.0)
	var disabled := pill(Color(CREAM.darkened(0.3), 0.75), BORDER, 0.0)
	disabled.border_color = Color(INK, 0.6)
	for style: StyleBoxFlat in [normal, hover, pressed, focus, disabled]:
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 6
		style.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(item, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.55))

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", OUTLINE)

	var panel := box(PANEL)
	panel.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	# Barre di scorrimento: pillola crema su un fondo scuro.
	for bar: String in ["VScrollBar", "HScrollBar"]:
		var track := pill(SOFT, 2)
		track.set_content_margin_all(2)
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("scroll_focus", bar, track)
		for state: Array in [["grabber", CREAM], ["grabber_highlight", CREAM.lerp(ACCENT, 0.5)], ["grabber_pressed", ACCENT]]:
			var grabber := pill(state[1], 2)
			grabber.set_content_margin_all(6)
			t.set_stylebox(state[0], bar, grabber)
	return t


## Grana leggera come sullo sfondo del sito: puntini chiari e scuri a caso,
## da ripetere sulla superficie.
static func grain_texture() -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in image.get_height():
		for x in image.get_width():
			var v := rng.randf()
			image.set_pixel(x, y, Color(0, 0, 0, 0.12 * v * v) if v > 0.4 else Color(1, 1, 1, 0.03 * v))
	return ImageTexture.create_from_image(image)
