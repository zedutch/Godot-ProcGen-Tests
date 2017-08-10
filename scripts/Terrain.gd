extends StaticBody

export(float) var terrain_resolution = 1
export(Vector2) var num_chunks = Vector2(3, 3)
export(Vector2) var chunk_size = Vector2(64, 64)
export(Vector2) var height_range = Vector2(0, 10)
export(float) var terrain_roughness = 1.0

export(bool) var smooth_normals = true
export(int) var smoothing_passes = 0

export(bool) var generate_collision_body = false

export(bool) var load_from_image = false
# If true, chunks will be resized to fit the set number of chunks in the image
# otherwise, it'll be the other way around
export(bool) var resize_chunks = false
export(String, FILE, "*.png,*.jpg") var image_path

export(float) var uv_scale = 1.0
export(Material) var material;
export(Material) var material2;

var TerrainChunk = preload("TerrainChunk.gd")
var chunks = []

onready var resolution = Vector2(terrain_resolution, terrain_resolution)

# For debugging:
func _ready():
	set_process_input(true)

func _input(event):
	if event is InputEventKey:
		if event.is_action("regen_map") and not event.is_pressed():
			print("Regenerating world!")
			generate()

func _init():
	clear()

func clear():
	chunks.clear()
	for child in get_children():
		remove_child(child)

# Generate the terrain based on the current settings
func generate():
	if load_from_image:
		load_heightmap()
	else:
		print("Should generate ", num_chunks, " chunks of terrain")

# Load the terrain from a heightmap image
# This ignores the number of chunks set
func load_heightmap(image = image_path):
	var img = Image.new()
	img.load(image)
	print("Finished loading image at " + image + ". Image resolution: " + str(img.get_width()) + "x" + str(img.get_height()))
	
	if resize_chunks:
		chunk_size.x = floor(img.get_width()  / num_chunks.x)
		chunk_size.y = floor(img.get_height() / num_chunks.y)
	else:
		num_chunks.x = floor(img.get_width()  / chunk_size.x)
		num_chunks.y = floor(img.get_height() / chunk_size.y)
	
	# chunk size has to be odd to properly stitch together -> alternate between chunk_size - 1 and chunk_size + 1 in that case
	var weave_x = int(chunk_size.x) % 2 == 0
	var weave_y = int(chunk_size.y) % 2 == 0

	var chunks = []
	chunks.resize(num_chunks.y)
	for j in range(num_chunks.y):
		chunks[j] = []
		chunks[j].resize(num_chunks.x)
		for i in range(num_chunks.x):
			var offset = Vector3(i * (chunk_size.x - 1) * resolution.x, 0, j * (chunk_size.y - 1) * resolution.y)
			offset.x += (resolution.x if weave_x and i % 2 == 1 else 0)
			offset.z += (resolution.y if weave_y and j % 2 == 1 else 0)
			print("Generating chunk (", i, ", ", j, ") at ", offset)
			var w = chunk_size.x + (1 if weave_x and i % 2 == 0 else (-1 if weave_x else 0))
			var h = chunk_size.y + (1 if weave_y and j % 2 == 0 else (-1 if weave_y else 0))
			var x = i * (chunk_size.x - 1) + (1 if weave_x and i % 2 == 1 else 0)
			var y = j * (chunk_size.y - 1) + (1 if weave_y and j % 2 == 1 else 0)
			var rect = Rect2(x, y, w, h)
			var subimg = img.get_rect(rect)
			chunks[j][i] = create_chunk()
			if i % 2 == j % 2:
				chunks[j][i].material = material2
			chunks[j][i].mapsize.x = w
			chunks[j][i].mapsize.y = h
			chunks[j][i].translation = offset
			chunks[j][i].generate(subimg)
			add_child(chunks[j][i], true)
	
	var start = OS.get_ticks_msec()
	for j in range(chunks.size()):
		for i in range(chunks[j].size()):
			var c = chunks[j][i]
			if j+1 <= chunks.size()-1:
				var off = c.translation - chunks[j+1][i].translation
				c.fix_seams(chunks[j+1][i], off)
			if i+1 <= chunks[j].size()-1:
				var off = c.translation - chunks[j][i+1].translation
				c.fix_seams(chunks[j][i+1], off)
			# TODO: Can't we simply update the normals without changing the vertices?
			chunks[j][i].regenerate()
	var t = OS.get_ticks_msec() - start
	print("Normal stitching took %d msec in total, ie. %d msec per chunk" % [t, t / (chunks.size() * chunks[0].size())])

func create_chunk():
	var chunk = TerrainChunk.new()
	chunk.terrain_resolution = terrain_resolution
	chunk.material = material
	chunk.height_range = height_range
	chunk.mapsize = chunk_size
	chunk.smooth_normals = smooth_normals
	chunk.smoothing_passes = smoothing_passes
	chunk.uv_scale = uv_scale
	chunk.terrain_roughness = terrain_roughness
	chunk.generate_collision_mesh = generate_collision_body
	return chunk