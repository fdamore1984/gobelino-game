class_name LightTexture
## Texture per le luci 2D (torcia, palla di fuoco): luce piena al centro
## che sfuma ai bordi, a forma di ellisse larga il doppio che alta, come un
## cerchio a terra visto nella prospettiva isometrica. Creata una volta sola
## e condivisa. C'è anche il fascio a cono della torcia elettrica (vedi
## get_cone_texture e Flashlight).

const SIZE := 512
const HEIGHT := 256
## Fascio a cono: texture quadrata col vertice al centro e il cono verso
## destra (+X), disegnata in pianta (Flashlight la schiaccia a terra).
## CONE_HALF_ANGLE è metà dell'apertura, CONE_SOFT la sfumatura dei bordi.
## Niente alone attorno al vertice: c'è solo il fascio.
const CONE_SIZE := 256
const CONE_HALF_ANGLE := deg_to_rad(40.0)
const CONE_SOFT := deg_to_rad(10.0)
## Il fascio si accende tra queste distanze dal vertice (frazioni della
## portata): la torcia non abbaglia chi la tiene.
const CONE_START := Vector2(0.02, 0.1)

static var _texture: GradientTexture2D
static var _cone: ImageTexture


static func get_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.55, Color(1, 1, 1, 0.55))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = SIZE
		_texture.height = HEIGHT
	return _texture


## Fascio della torcia elettrica: pieno poco davanti al vertice, si spegne
## verso la fine della portata (metà della texture) e ai bordi del cono.
static func get_cone_texture() -> ImageTexture:
	if _cone == null:
		var image := Image.create(CONE_SIZE, CONE_SIZE, false, Image.FORMAT_RGBA8)
		var middle := Vector2(CONE_SIZE, CONE_SIZE) / 2.0
		for x in CONE_SIZE:
			for y in CONE_SIZE:
				var offset := (Vector2(x + 0.5, y + 0.5) - middle) / middle.x
				var distance := offset.length()
				var beam := 0.0
				if distance < 1.0:
					var side := absf(offset.angle())
					beam = (1.0 - smoothstep(CONE_HALF_ANGLE - CONE_SOFT, CONE_HALF_ANGLE + CONE_SOFT, side)) \
							* (1.0 - smoothstep(0.45, 1.0, distance)) * smoothstep(CONE_START.x, CONE_START.y, distance)
				image.set_pixel(x, y, Color(1, 1, 1, clampf(beam, 0.0, 1.0)))
		_cone = ImageTexture.create_from_image(image)
	return _cone
