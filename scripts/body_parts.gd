class_name BodyParts
## Parti del corpo disegnate con forme geometriche, comuni a giocatore e
## nemici: gambe che camminano e spada che fende. Provvisorie, in attesa
## degli sprite definitivi.

const COLOR_BLADE := Color(0.86, 0.88, 0.92)
const COLOR_EDGE := Color(1.0, 1.0, 1.0)
const COLOR_GUARD := Color(0.55, 0.42, 0.2)
const COLOR_GRIP := Color(0.32, 0.2, 0.12)
## Prospettiva isometrica: chi guarda verso nord (verso l'alto dello
## schermo, sguardo con y sotto questa soglia) ha davanti a sé la parte del
## corpo lontana dalla telecamera, e gli elementi montati sul corpo (armi,
## braccia, torcia, scorte, faccia) vanno disegnati prima del corpo, che li
## copre; guardando a sud restano davanti al corpo.
const BEHIND_FACING := -0.2


## True se gli elementi montati sul corpo vanno dietro al corpo (vedi BEHIND_FACING).
static func gear_behind(facing: Vector2) -> bool:
	return facing.y < BEHIND_FACING


## Due gambe dai fianchi ai piedi. phase avanza camminando: i piedi si
## spostano avanti e indietro lungo la direzione di movimento (direction);
## stride 0 = fermi o in aria.
static func draw_legs(canvas: CanvasItem, hip_y: float, foot_y: float, spacing: float, width: float,
		phase: float, direction: Vector2, stride: float, color: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var swing := direction * sin(phase + (PI if side > 0.0 else 0.0)) * stride
		var hip := Vector2(side * spacing, hip_y)
		var foot := Vector2(side * spacing, foot_y) + Vector2(swing.x, swing.y * 0.5)
		# Contorno a inchiostro sotto la gamba e il piede (stile fumetto).
		canvas.draw_line(hip, foot, Color(Shapes.INK, color.a), width + Shapes.INK_WIDTH * 1.5)
		Shapes.ink_disc(canvas, foot, width * 0.6, color.darkened(0.25), Shapes.INK_WIDTH * 0.75)
		canvas.draw_line(hip, foot, color, width)


## Spada che parte da origin con l'angolo dato: impugnatura, guardia e lama
## che si assottiglia verso la punta.
static func draw_sword(canvas: CanvasItem, origin: Vector2, angle: float, length: float, width: float, tint := Color.WHITE) -> void:
	var direction := Vector2.from_angle(angle)
	var side := direction.orthogonal()
	var grip_end := origin + direction * length * 0.18
	var tip := origin + direction * length
	canvas.draw_line(origin, grip_end, COLOR_GRIP, width * 0.8)
	canvas.draw_line(grip_end - side * width * 1.4, grip_end + side * width * 1.4, COLOR_GUARD, width * 0.7)
	# Lama: un quadrilatero che si assottiglia e la punta (primitive, che
	# costano meno dei poligoni da ridisegnare a ogni frame).
	var shoulder := tip - direction * width * 1.2
	# Contorno a inchiostro: impugnatura, guardia e lama un po' più grandi, sotto.
	var ink := Shapes.INK_WIDTH * 0.7
	var inks := PackedColorArray([Color(Shapes.INK, tint.a)])
	canvas.draw_line(origin - direction * ink, grip_end, inks[0], width * 0.8 + ink * 2.0)
	canvas.draw_line(grip_end - side * (width * 1.4 + ink), grip_end + side * (width * 1.4 + ink), inks[0], width * 0.7 + ink * 2.0)
	canvas.draw_primitive(PackedVector2Array([grip_end + side * (width * 0.55 + ink), shoulder + side * (width * 0.4 + ink),
			shoulder - side * (width * 0.4 + ink), grip_end - side * (width * 0.55 + ink)]), inks, PackedVector2Array())
	canvas.draw_primitive(PackedVector2Array([shoulder + side * (width * 0.4 + ink), tip + direction * ink * 1.8,
			shoulder - side * (width * 0.4 + ink)]), inks, PackedVector2Array())
	var colors := PackedColorArray([COLOR_BLADE * tint])
	canvas.draw_primitive(PackedVector2Array([grip_end + side * width * 0.55, shoulder + side * width * 0.4,
			shoulder - side * width * 0.4, grip_end - side * width * 0.55]), colors, PackedVector2Array())
	canvas.draw_primitive(PackedVector2Array([shoulder + side * width * 0.4, tip, shoulder - side * width * 0.4]), colors, PackedVector2Array())
	canvas.draw_line(grip_end, tip - direction * width, COLOR_EDGE * tint, maxf(width * 0.25, 1.0))


## Scia del fendente: una fascia ad arco tra from_angle e to_angle, più
## accesa verso il bordo che si sta muovendo.
static func draw_trail(canvas: CanvasItem, center: Vector2, from_angle: float, to_angle: float,
		inner: float, outer: float, color: Color) -> void:
	var steps := 14
	for i in steps:
		var a := lerpf(from_angle, to_angle, float(i) / steps)
		var b := lerpf(from_angle, to_angle, float(i + 1) / steps)
		var piece := PackedVector2Array([
			center + Vector2.from_angle(a) * inner, center + Vector2.from_angle(a) * outer,
			center + Vector2.from_angle(b) * outer, center + Vector2.from_angle(b) * inner,
		])
		canvas.draw_primitive(piece, PackedColorArray([Color(color, color.a * float(i + 1) / steps)]), PackedVector2Array())
