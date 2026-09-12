extends Reference

# ShadowFactory — purely visual soft-shadow helpers for board elements.

const BORDER_RADIUS = 15.0
const BLUR_SIZE = 5.0
const SHADOW_ALPHA = 0.40

const SHADOW_CODE = """
shader_type canvas_item;

uniform vec2 rect_size_px = vec2(100.0, 100.0);
uniform float radius_px = 15.0;
uniform float blur_px = 5.0;
uniform float shadow_alpha = 0.40;

void fragment() {
	// Coordinate in pixel, con (0,0) al centro del rettangolo.
	vec2 p = (UV - vec2(0.5)) * rect_size_px;

	// Lascia spazio ai bordi per la sfumatura.
	vec2 half_size = rect_size_px * 0.5 - vec2(blur_px);

	// Evita radius maggiori della dimensione disponibile.
	float r = min(
		radius_px,
		min(half_size.x, half_size.y)
	);

	// Signed Distance Function di un rettangolo arrotondato.
	vec2 q = abs(p) - half_size + vec2(r);

	float sd =
		length(max(q, vec2(0.0))) +
		min(max(q.x, q.y), 0.0) -
		r;

	// Ombra piena all'interno, sfumata verso l'esterno.
	float alpha =
		(1.0 - smoothstep(-blur_px, blur_px, sd))
		* shadow_alpha;

	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""


func make_material(rect_size):
	var shader = Shader.new()
	shader.code = SHADOW_CODE

	var material = ShaderMaterial.new()
	material.shader = shader

	material.set_shader_param("rect_size_px", rect_size)
	material.set_shader_param("radius_px", BORDER_RADIUS)
	material.set_shader_param("blur_px", BLUR_SIZE)
	material.set_shader_param("shadow_alpha", SHADOW_ALPHA)

	return material


# Una sola ombra sotto l'intera pila.
# start_visible permette di creare l'ombra inizialmente nascosta,
# utile per la pila degli Scarti quando è ancora vuota.
func add_pile_shadow(
	parent,
	pos,
	size,
	offset = Vector2(5, 9),
	start_visible = true
):
	if parent == null:
		return null

	var blur_margin = Vector2(BLUR_SIZE, BLUR_SIZE)

	var sh = ColorRect.new()
	sh.name = "SoftShadow"
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Rettangolo più grande della pila per lasciare spazio alla sfumatura.
	sh.rect_size = size + blur_margin * 2.0

	# Compensa l'ingrandimento e poi applica l'offset dell'ombra.
	sh.rect_position = pos - blur_margin + offset

	sh.material = make_material(sh.rect_size)

	# Permette, ad esempio, di nascondere inizialmente
	# l'ombra della pila degli Scarti.
	sh.visible = start_visible

	parent.add_child(sh)
	parent.move_child(sh, 0)

	return sh


# Mostra o nasconde l'ombra di una pila.
func set_pile_shadow_visible(shadow, visible):
	if shadow != null and is_instance_valid(shadow):
		shadow.visible = visible


# Ombra di una singola carta CPU.
func make_card_shadow(pos, size, rot_deg, pivot_offset):
	var blur_margin = Vector2(BLUR_SIZE, BLUR_SIZE)

	var sh = ColorRect.new()
	sh.name = "SoftShadow"
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE

	sh.rect_size = size + blur_margin * 2.0
	sh.rect_position = pos - blur_margin + Vector2(3, 6)

	# Siccome abbiamo aggiunto BLUR_SIZE intorno alla carta,
	# anche il pivot deve essere traslato dello stesso valore.
	sh.rect_pivot_offset = pivot_offset + blur_margin
	sh.rect_rotation = rot_deg

	sh.material = make_material(sh.rect_size)

	return sh