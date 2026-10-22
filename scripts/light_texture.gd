class_name LightTexture
## Texture per le luci 2D (torcia, palla di fuoco): luce piena al centro
## che sfuma ai bordi, a forma di ellisse larga il doppio che alta, come un
## cerchio a terra visto nella prospettiva isometrica. Creata una volta sola
## e condivisa.

const SIZE := 512
const HEIGHT := 256

static var _texture: GradientTexture2D


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
