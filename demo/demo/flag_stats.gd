extends Tree

const GRAPH_COL := 1
const MS_COL := 2
const FPS_COL := 3

const GRAPH_W := 40
const GRAPH_H := 14
const HISTORY_SIZE := 24
## Exponential smoothing factor for the displayed text values.
const SMOOTH_ALPHA := 0.3

# Per-stats-path state, kept across Tree clears so trends survive.
var _histories := {}  # path -> PackedFloat32Array of raw us values
var _smoothed := {}   # path -> float (exponentially smoothed us)
var _images := {}     # path -> Image, reused and redrawn in place
var _textures := {}   # path -> ImageTexture, updated in place

func _on_flag_stats_changed(stats: Dictionary) -> void:
	clear()
	set_column_title(0, "Name")
	set_column_expand(0, true)
	set_column_title(GRAPH_COL, "Trend")
	set_column_expand(GRAPH_COL, false)
	set_column_custom_minimum_width(GRAPH_COL, GRAPH_W + 6)
	set_column_title(MS_COL, "MS")
	set_column_expand(MS_COL, false)
	set_column_custom_minimum_width(MS_COL, 50)
	set_column_title(FPS_COL, "FPS")
	set_column_expand(FPS_COL, false)
	set_column_custom_minimum_width(FPS_COL, 60)
	var root := create_item()
	_add_stats(root, stats, "")

func _add_stats(parent: TreeItem, stats: Dictionary, prefix: String) -> void:
	for ch in stats["children"]:
		var path := prefix + "/" + str(ch["name"])
		var it := parent.create_child()
		it.set_text(0, ch["name"])
		_update_graph(it, path, ch["us"])
		var smooth_us := _smooth(path, ch["us"])
		it.set_text(MS_COL, "%.2f" % (smooth_us / 1000.0))
		it.set_text_alignment(MS_COL, HORIZONTAL_ALIGNMENT_RIGHT)
		it.set_text(FPS_COL, "%.0f" % (1000000.0 / maxf(smooth_us, 1.0)))
		it.set_text_alignment(FPS_COL, HORIZONTAL_ALIGNMENT_RIGHT)
		if "children" in ch:
			_add_stats(it, ch, path)

## Exponential moving average of `value`, so the numbers don't jump every frame.
func _smooth(path: String, value: float) -> float:
	if _smoothed.has(path):
		var s := lerpf(_smoothed[path], value, SMOOTH_ALPHA)
		_smoothed[path] = s
		return s
	_smoothed[path] = value
	return value

## Draws a color-coded sparkline of the raw value history into the graph column.
## Green = improving (lower), red = worsening (higher), grey = flat/unchanged.
func _update_graph(it: TreeItem, path: String, value: float) -> void:
	var hist: PackedFloat32Array = _histories.get(path, PackedFloat32Array())
	hist.push_back(value)
	if hist.size() > HISTORY_SIZE:
		hist = hist.slice(hist.size() - HISTORY_SIZE, hist.size())
	_histories[path] = hist
	if hist.size() < 2:
		return

	var img: Image
	if _images.has(path):
		img = _images[path]
	else:
		img = Image.create(GRAPH_W, GRAPH_H, false, Image.FORMAT_RGBA8)
		_images[path] = img
	img.fill(Color(0, 0, 0, 0))

	var mn := INF
	var mx := -INF
	for v in hist:
		mn = minf(mn, v)
		mx = maxf(mx, v)
	if mx - mn < 1e-9:
		mn = mx - 1.0
	var span := mx - mn

	var n := hist.size()
	var trend := hist[n - 1] - hist[maxi(n - 4, 0)]
	var color := Color(0.55, 0.55, 0.55)
	if absf(trend) / maxf(mx, 1.0) > 0.02:
		color = Color(0.25, 0.8, 0.35) if trend < 0.0 else Color(0.85, 0.3, 0.25)

	var prev := Vector2i(-1, -1)
	for i in n:
		var x := int(round(1.0 + float(i) / float(n - 1) * float(GRAPH_W - 2)))
		var t := (hist[i] - mn) / span
		var y := int(round(2.0 + (1.0 - t) * float(GRAPH_H - 4)))
		var pt := Vector2i(x, y)
		if i > 0:
			_line(img, prev, pt, color)
		prev = pt

	var tex: ImageTexture
	if _textures.has(path):
		tex = _textures[path]
	else:
		tex = ImageTexture.create_from_image(img)
		_textures[path] = tex
	tex.update(img)
	it.set_icon(GRAPH_COL, tex)

## Bresenham line into a small image (Image has no draw_line in Godot 4.7).
func _line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		img.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
