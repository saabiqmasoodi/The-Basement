extends SceneTree
# Generates the grime, decal and fabric textures used by the horror pass.
# Run headless:
#   Godot --headless --path . -s res://tools/generate_horror_textures.gd
# The PNGs are committed to materials/generated so the game does not need
# to synthesize them at runtime.

const OUT := "res://materials/generated/"
const DECAL_SIZE := 1024
const FABRIC_SIZE := 512
const LENS_SIZE := 1024

var n_soft: FastNoiseLite
var n_fine: FastNoiseLite
var n_streak: FastNoiseLite
var n_blob: FastNoiseLite
var n_dust: FastNoiseLite


func _initialize() -> void:
	n_soft = _noise(11, 0.0035, 4, 0.55)
	n_fine = _noise(27, 0.018, 4, 0.5)
	n_streak = _noise(41, 0.010, 3, 0.6)
	n_blob = _noise(73, 0.006, 4, 0.55)
	n_dust = _noise(97, 0.030, 3, 0.5)
	_make_water_stain()
	_make_rust()
	_make_mold()
	_make_blood()
	_make_handprint()
	_make_puddle()
	_make_hazard()
	_make_scratches()
	_make_lens_dirt()
	_make_fabric()
	print("HORROR_TEXTURES_DONE")
	quit()


func _noise(seed: int, freq: float, octaves: int, gain: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.fractal_lacunarity = 2.0
	return n


func _n01(n: FastNoiseLite, x: float, y: float) -> float:
	return (n.get_noise_2d(x, y) + 1.0) * 0.5


func _save(img: Image, name: String) -> void:
	var path := OUT + name
	var err := img.save_png(path)
	print("TEXTURE ", path, " err=", err, " ", img.get_width(), "x", img.get_height())
	if err != OK:
		push_error("Could not save " + path)


func _make_water_stain() -> void:
	var img := Image.create(DECAL_SIZE, DECAL_SIZE, false, Image.FORMAT_RGBA8)
	for y in DECAL_SIZE:
		for x in DECAL_SIZE:
			var u := float(x) / DECAL_SIZE
			var v := float(y) / DECAL_SIZE
			var nx := (u - 0.5) * 1.22
			var ny := (v - 0.48) * 1.55
			var r := sqrt(nx * nx + ny * ny)
			var edge := 0.53 + (_n01(n_blob, x, y) - 0.5) * 0.26
			var body := 1.0 - smoothstep(edge - 0.10, edge, r)
			# Vertical leaks from the top lip of the stain.
			var streak := smoothstep(0.57, 0.78, _n01(n_streak, x * 0.75, y * 2.6))
			streak *= smoothstep(0.02, 0.30, v) * (1.0 - smoothstep(0.45, 0.95, v))
			var a := clampf(body * 0.92 + streak * 0.48, 0.0, 1.0)
			# Keep a ragged, slightly transparent edge instead of a solid blob.
			a *= 0.72 + 0.28 * _n01(n_fine, x, y)
			var grime := _n01(n_fine, x * 2.0, y * 2.0)
			var c := Color(0.035 + grime * 0.030, 0.052 + grime * 0.040, 0.043 + grime * 0.030, a)
			img.set_pixel(x, y, c)
	_save(img, "decal_water.png")


func _make_rust() -> void:
	var img := Image.create(DECAL_SIZE, DECAL_SIZE, false, Image.FORMAT_RGBA8)
	for y in DECAL_SIZE:
		for x in DECAL_SIZE:
			var u := float(x) / DECAL_SIZE
			var v := float(y) / DECAL_SIZE
			var base := smoothstep(0.53, 0.78, _n01(n_blob, x, y * 0.65))
			var fine := _n01(n_fine, x * 1.7, y * 1.7)
			var streak := smoothstep(0.62, 0.80, _n01(n_streak, x * 0.9, y * 3.8))
			streak *= smoothstep(0.02, 0.22, v) * (1.0 - smoothstep(0.55, 1.0, v))
			var a := clampf(base * (0.35 + fine * 0.55) + streak * 0.65, 0.0, 0.92)
			var c := Color(
				0.20 + fine * 0.17 + streak * 0.10,
				0.085 + fine * 0.075 + streak * 0.035,
				0.030 + fine * 0.025,
				a
			)
			img.set_pixel(x, y, c)
	_save(img, "decal_rust.png")


func _make_mold() -> void:
	var img := Image.create(DECAL_SIZE, DECAL_SIZE, false, Image.FORMAT_RGBA8)
	for y in DECAL_SIZE:
		for x in DECAL_SIZE:
			var u := float(x) / DECAL_SIZE
			var v := float(y) / DECAL_SIZE
			var nx := (u - 0.50) * 1.1
			var ny := (v - 0.50) * 1.35
			var r := sqrt(nx * nx + ny * ny)
			var edge := 0.40 + (_n01(n_blob, x * 1.6, y * 1.6) - 0.5) * 0.34
			var body := 1.0 - smoothstep(edge - 0.14, edge, r)
			var specks := smoothstep(0.63, 0.82, _n01(n_fine, x * 3.2, y * 3.2))
			var a := clampf(body * (0.25 + specks * 0.72), 0.0, 0.88)
			var c := Color(
				0.030 + specks * 0.035, 0.052 + specks * 0.060, 0.027 + specks * 0.022, a
			)
			img.set_pixel(x, y, c)
	_save(img, "decal_mold.png")


func _make_blood() -> void:
	var img := Image.create(DECAL_SIZE, DECAL_SIZE, false, Image.FORMAT_RGBA8)
	for y in DECAL_SIZE:
		for x in DECAL_SIZE:
			var u := float(x) / DECAL_SIZE
			var v := float(y) / DECAL_SIZE
			var nx := (u - 0.50) * 1.0
			var ny := (v - 0.50) * 1.25
			var r := sqrt(nx * nx + ny * ny)
			var edge := 0.48 + (_n01(n_blob, x * 1.4, y * 1.4) - 0.5) * 0.30
			var body := 1.0 - smoothstep(edge - 0.13, edge, r)
			var smear := smoothstep(0.61, 0.76, _n01(n_streak, x * 0.8, y * 2.2))
			smear *= smoothstep(0.1, 0.4, v) * (1.0 - smoothstep(0.6, 1.0, v))
			var a := clampf(body * (0.55 + _n01(n_fine, x, y) * 0.40) + smear * 0.38, 0.0, 0.95)
			var c := Color(0.15 + a * 0.055, 0.018 + a * 0.012, 0.016 + a * 0.010, a * 0.86)
			img.set_pixel(x, y, c)
	_save(img, "decal_blood.png")


func _make_handprint() -> void:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var a := 0.0
			# Palm.
			a = maxf(a, _ellipse(u, v, 0.50, 0.66, 0.135, 0.115))
			# Fingers. The middle two are longest.
			var fx := [0.395, 0.455, 0.520, 0.582, 0.635]
			var fy := [0.47, 0.40, 0.365, 0.40, 0.47]
			var fr := [0.046, 0.052, 0.054, 0.050, 0.043]
			for i in 5:
				a = maxf(a, _ellipse(u, v, fx[i], fy[i], fr[i], fr[i] * 1.75))
			# Thumb.
			a = maxf(a, _ellipse(u, v, 0.345, 0.61, 0.055, 0.035))
			# Ragged, smeared edges and a dry palm centre.
			var rag := _n01(n_fine, x * 2.2, y * 2.2)
			a *= smoothstep(0.26, 0.47, rag + a * 0.52)
			a *= 0.70 + 0.30 * smoothstep(0.35, 0.55, _n01(n_blob, x, y))
			a = clampf(a, 0.0, 0.86)
			var c := Color(0.105 + a * 0.04, 0.012, 0.010, a)
			img.set_pixel(x, y, c)
	_save(img, "decal_handprint.png")


func _ellipse(u: float, v: float, cx: float, cy: float, rx: float, ry: float) -> float:
	var dx := (u - cx) / rx
	var dy := (v - cy) / ry
	var d := sqrt(dx * dx + dy * dy)
	return 1.0 - smoothstep(0.82, 1.0, d)


func _make_puddle() -> void:
	var size := 1024
	var albedo := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var normal := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var orm := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var nx := (u - 0.5) * 1.15
			var ny := (v - 0.5) * 1.5
			var r := sqrt(nx * nx + ny * ny)
			var edge := 0.48 + (_n01(n_blob, x * 1.3, y * 1.3) - 0.5) * 0.32
			var a := 1.0 - smoothstep(edge - 0.08, edge, r)
			a *= 0.65 + 0.35 * _n01(n_fine, x * 1.5, y * 1.5)
			a = clampf(a, 0.0, 1.0)
			var h := _n01(n_soft, x, y) * 0.35 + _n01(n_fine, x * 1.7, y * 1.7) * 0.12
			# A few soft concentric ripples.
			h += sin(r * 34.0 + _n01(n_blob, x * 0.4, y * 0.4) * 6.0) * 0.018
			heights[y * size + x] = h
			var c := Color(0.012, 0.017, 0.020, a * 0.90)
			albedo.set_pixel(x, y, c)
			var rough := lerpf(0.86, 0.035, smoothstep(0.15, 0.55, a))
			orm.set_pixel(x, y, Color(1.0, rough, 0.0, a))
	var strength := 6.0
	for y in size:
		var y0 := maxi(y - 1, 0)
		var y1 := mini(y + 1, size - 1)
		for x in size:
			var x0 := maxi(x - 1, 0)
			var x1 := mini(x + 1, size - 1)
			var hl := heights[y * size + x0]
			var hr := heights[y * size + x1]
			var hd := heights[y0 * size + x]
			var hu := heights[y1 * size + x]
			var n := Vector3((hl - hr) * strength, (hd - hu) * strength, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	_save(albedo, "decal_puddle.png")
	_save(normal, "decal_puddle_normal.png")
	_save(orm, "decal_puddle_orm.png")


func _make_hazard() -> void:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var stripe := fposmod((u + v) * 7.0, 1.0)
			var yellow := stripe > 0.5
			var wear := _n01(n_fine, x * 1.8, y * 1.8)
			var edge_wear := (
				smoothstep(0.02, 0.10, u)
				* smoothstep(0.02, 0.10, v)
				* (1.0 - smoothstep(0.90, 0.98, u))
				* (1.0 - smoothstep(0.90, 0.98, v))
			)
			var a := 0.88 * edge_wear * smoothstep(0.36, 0.48, wear)
			var c := Color(0.44, 0.30, 0.022, a) if yellow else Color(0.035, 0.030, 0.025, a)
			img.set_pixel(x, y, c)
	_save(img, "decal_hazard.png")


func _make_scratches() -> void:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	# Scratches are thin, slightly irregular diagonal lines.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8711
	for i in 26:
		var cx := rng.randf_range(0.08, 0.92) * size
		var cy := rng.randf_range(0.08, 0.92) * size
		var length := rng.randf_range(18.0, 70.0)
		var angle := rng.randf_range(-1.15, 1.15)
		var width := rng.randf_range(0.7, 1.8)
		var dx := cos(angle)
		var dy := sin(angle)
		for t in int(length):
			var px := int(cx + dx * t)
			var py := int(cy + dy * t)
			for ox in range(-2, 3):
				for oy in range(-2, 3):
					var qx := px + ox
					var qy := py + oy
					if qx < 0 or qy < 0 or qx >= size or qy >= size:
						continue
					var d := absf(ox * dy - oy * dx)
					var a := smoothstep(width + 1.2, width - 0.4, d) * 0.42
					var prev := img.get_pixel(qx, qy)
					if a > prev.a:
						img.set_pixel(qx, qy, Color(0.55, 0.56, 0.52, a))
	_save(img, "decal_scratches.png")


func _make_lens_dirt() -> void:
	var size := LENS_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var low := _n01(n_soft, x * 1.4, y * 1.4)
			var mid := _n01(n_blob, x * 2.3, y * 2.3)
			var fine := _n01(n_dust, x * 1.9, y * 1.9)
			var smudge := smoothstep(0.48, 0.72, low * 0.65 + mid * 0.35)
			var specks := smoothstep(0.86, 0.97, fine) * 0.8
			var edge := smoothstep(0.12, 0.50, Vector2(u, v).distance_to(Vector2(0.5, 0.5)))
			var d := clampf((smudge * 0.70 + specks) * edge, 0.0, 1.0)
			var c := Color(0.42 + mid * 0.25, 0.39 + mid * 0.22, 0.34 + mid * 0.18, d)
			img.set_pixel(x, y, c)
	_save(img, "lens_dirt.png")


func _make_fabric() -> void:
	var size := FABRIC_SIZE
	var albedo := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var normal := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rough := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var weave := (sin(u * TAU * 72.0) + sin(v * TAU * 72.0)) * 0.5
			weave = weave * 0.5 + 0.5
			var n := _n01(n_soft, x * 1.4, y * 1.4) * 0.55 + _n01(n_fine, x * 2.2, y * 2.2) * 0.45
			var stain := smoothstep(0.58, 0.78, _n01(n_blob, x * 1.7, y * 1.7)) * 0.55
			var val := 0.54 + weave * 0.06 + (n - 0.5) * 0.10
			val = lerpf(val, val * 0.42, stain)
			var c := Color(val * 0.96, val * 0.94, val * 0.90, 1.0)
			albedo.set_pixel(x, y, c)
			var h := weave * 0.35 + (n - 0.5) * 0.25
			heights[y * size + x] = h
			var r := clampf(0.78 + (n - 0.5) * 0.22 + stain * 0.15, 0.0, 1.0)
			rough.set_pixel(x, y, Color(r, r, r, 1.0))
	var strength := 2.0
	for y in size:
		var y0 := maxi(y - 1, 0)
		var y1 := mini(y + 1, size - 1)
		for x in size:
			var x0 := maxi(x - 1, 0)
			var x1 := mini(x + 1, size - 1)
			var hl := heights[y * size + x0]
			var hr := heights[y * size + x1]
			var hd := heights[y0 * size + x]
			var hu := heights[y1 * size + x]
			var nrm := Vector3((hl - hr) * strength, (hd - hu) * strength, 1.0).normalized()
			normal.set_pixel(
				x, y, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, nrm.z * 0.5 + 0.5, 1.0)
			)
	_save(albedo, "friend_fabric_albedo.png")
	_save(normal, "friend_fabric_normal.png")
	_save(rough, "friend_fabric_roughness.png")
