shader_type spatial;
// 背景圖：不受光照，深度一律寫成最遠，所以場景裡所有 3D 物件都會畫在它前面，
// 不管背景實際放在攝影機前方多遠（大型模型穿過背景位置也不會被切掉）。
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D backdrop_texture : source_color, filter_linear_mipmap;

void fragment() {
	ALBEDO = texture(backdrop_texture, UV).rgb;
	// Godot 4 使用反向深度：0 是最遠。寫一個極小的值，比清除值 0 近一點點，
	// 讓背景能畫上去，但任何實際物件的深度都比它大（比較近）。
	DEPTH = 0.000001;
}
