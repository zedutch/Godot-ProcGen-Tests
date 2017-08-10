extends "Primitive.gd"

export(String, "Flat", "Random", "Midpoint") var algorithm;
export(Material) var material;
export(float) var terrain_resolution = 1.0
# The higher uv_scale is, the bigger the textures will be.
export(float) var uv_scale = 1.0
export(Vector2) var mapsize = Vector2(129, 129)
export(Vector2) var height_range = Vector2(0, 10)
export(float) var terrain_roughness = 2.0

export(bool) var smooth_normals = false
export(int)  var smoothing_passes = 0

export(bool) var save_image = false
export(String, DIR) var output_dir

export(bool) var load_from_image = false
export(String, FILE, "*.png,*.jpg") var image_path

onready var roughness = terrain_roughness * terrain_resolution

var dict_normals = {}
var uv_start
var uv_size
var vertices

# For debugging:
func _ready():
	set_process_input(true)

func _input(event):
	if event is InputEventKey:
		if event.is_action("regen_chunk") and not event.is_pressed():
			print("Regenerating chunk!")
			generate()

# Generate the terrain based on the current settings
func generate(from_image=null):
	clear()
	begin()
	st.set_material(material)
	
	# terrain_resolution used to be different for x and y, with a ratio of sqrt(3)/2 to get equilateral triangles,
	# but this caused issues with chunk stitching so I set the ratio to 1.0
	var resolution = Vector2(terrain_resolution, terrain_resolution)
	
	# 1 whole texture per hexagon if uv_scale is 1:
	uv_start = Vector2(0, 0)
	uv_size  = Vector2(2*resolution.x, 2*resolution.y)
	
	if from_image != null and from_image is Image:
		vertices = load_heightmap_from_image(resolution, from_image)
	elif load_from_image:
		vertices = load_heightmap(resolution)
	else:
		vertices = generate_terrain(resolution)
	if smoothing_passes > 0:
		var time_start = OS.get_ticks_msec()
		var sp = smoothing_passes
		while sp > 0:
			print("Starting smoothing pass ", smoothing_passes - sp + 1)
			smooth_terrain(vertices)
			sp -= 1
		var time_end = OS.get_ticks_msec()
		print("Smoothing took %d msec in total, ie. %d msec per pass." % [(time_end - time_start), (time_end - time_start) / smoothing_passes])
	if save_image and not load_from_image:
		save_heightmap(vertices)
	create_mesh(vertices, uv_start, uv_size)
	end(not smooth_normals)

func regenerate():
	clear()
	begin()
	st.set_material(material)
	
	var resolution = Vector2(terrain_resolution, terrain_resolution)
	
	# 1 whole texture per hexagon if uv_scale is 1:
	uv_start = Vector2(0, 0)
	uv_size  = Vector2(2*resolution.x, 2*resolution.y)
	
	create_mesh(vertices, uv_start, uv_size, true)
	end(not smooth_normals)

# Save the current terrain to a heightmap image
func save_heightmap(vertices):
	var img = Image.new()
	img.create(int(mapsize.x), int(mapsize.y), false, Image.FORMAT_L8)
	img.lock()
	for j in range(vertices.size()):
		var row = vertices[j]
		for i in range(row.size()):
			var p = row[i]
			img.set_pixel(i, j, height_to_grayscale(p))
	var d = OS.get_datetime()
	var date = str(d.year) + "_" + str(d.month) + "_" + str(d.day) + "-" + str(d.hour) + "_" + str(d.minute) + "_" + str(d.second)
	var filename = output_dir + "/" + algorithm + "_" + date + ".png"
	print("Saving image at " + filename)
	img.save_png(filename)
	img.unlock()
	return img

# Load the terrain from a heightmap image filepath
func load_heightmap(resolution, image = image_path):
	var img = Image.new()
	img.load(image)
	print("Finished loading image at " + image + ". Image resolution: " + str(img.get_width()) + "x" + str(img.get_height()))
	return load_heightmap_from_image(resolution, img)

# Load the terrain from a heightmap image
func load_heightmap_from_image(resolution, img):
	mapsize.x = img.get_width()
	mapsize.y = img.get_height()
	var vertices = gen_flat(resolution)
	img.lock()
	for j in range(img.get_height()):
		for i in range(img.get_width()):
			var h = img.get_pixel(i, j).gray()
			var height = height_range.x + h * (height_range.y - height_range.x)
			vertices[j][i].y = height
	img.unlock()
	return vertices

# Generate the terrain base on the algorithm set
func generate_terrain(resolution):
	var time_start = OS.get_ticks_msec()
	var vertices
	match algorithm:
		"Flat":     vertices = gen_flat(resolution, height_range.x)
		"Random":   vertices = gen_random(resolution)
		"Midpoint": vertices = gen_midpoint_displacement(resolution)
		_:
			print("Unknown algorithm: ", algorithm)
			vertices = gen_flat(resolution, height_range.x)
	var time_gen = OS.get_ticks_msec()
	print("Time to generate " + str(mapsize.x) + "x" + str(mapsize.y) + " chunk: " + str(time_gen - time_start))
	return vertices

# Convert a vertex height to a grayscale value
func height_to_grayscale(vertex):
	var perc = (vertex.y - height_range.x) / (height_range.y - height_range.x)
	var col = Color(perc, perc, perc)
	return col

# Use midpoint displacement map generation
func gen_midpoint_displacement(resolution):
	# Make sure the map size is 2^n + 1, which is necessary for midpoint displacement
	var size = min(mapsize.x, mapsize.y)
	if not M.is_int(M.log2(size - 1)):
		print("Map size ", size, " is not a power of 2 + 1, resizing map for midpoint displacement!")
		var expon = ceil(M.log2(size-1))
		size = pow(2, expon) + 1
		mapsize.x = size
		mapsize.y = size
		print("New map size: ", mapsize)
		
	var vertices = gen_flat(resolution, -1)
	randomize()
	
	# Initial corner seeds
	var d = min(mapsize.x-1, mapsize.y-1)
	vertices[0][0].y = rand_range(height_range.x, height_range.y)
	vertices[0][d].y = rand_range(height_range.x, height_range.y)
	vertices[d][d].y = rand_range(height_range.x, height_range.y)
	vertices[d][0].y = rand_range(height_range.x, height_range.y)
	d /= 2

	# The actual algorithm
	while d >= 1:
		for x in range(d, mapsize.x - 1, 2 * d):
			for y in range(d, mapsize.y - 1, 2 * d):
				md_square(vertices, x, y, d)
		for x in range(d, mapsize.x - 1, 2 * d):
			for y in range(0, mapsize.y, 2*d):
				md_diamond(vertices, x, y, d)
		for x in range(0, mapsize.x, 2 * d):
			for y in range(d, mapsize.y - 1, 2 * d):
				md_diamond(vertices, x, y, d)
		d /= 2
	return vertices

func md_square(vert, x, y, d):
	var sum = 0
	var num = 0
	if x-d >= 0:
		if y-d >= 0:
			sum += vert[y-d][x-d].y
			num += 1
		if y+d <= mapsize.y - 1:
			sum += vert[y+d][x-d].y
			num += 1
	if x+d <= mapsize.x - 1:
		if y-d >= 0:
			sum += vert[y-d][x+d].y
			num += 1
		if y+d <= mapsize.y - 1:
			sum += vert[y+d][x+d].y
			num += 1
	vert[y][x].y = md_get_height(sum / num, d)

func md_diamond(vert, x, y, d):
	var sum = 0
	var num = 0
	if x-d >= 0:
		sum += vert[y][x-d].y
		num += 1
	if x+d <= mapsize.x - 1:
		sum += vert[y][x+d].y
		num += 1
	if y-d >= 0:
		sum += vert[y-d][x].y
		num += 1
	if y+d <= mapsize.y - 1:
		sum += vert[y+d][x].y
		num += 1
	vert[y][x].y = md_get_height(sum / num, d)

func md_get_height(average, d):
	var distance_ratio = d / min(mapsize.x - 1, mapsize.y - 1)
	var displacement = (rand_range(0, height_range.y - height_range.x) - (height_range.y - height_range.x) / 2) * roughness * distance_ratio
	return clamp(average + displacement, height_range.x, height_range.y)
	
# Generate a completely random map
func gen_random(resolution):
	var vertices = gen_flat(resolution)
	for i in range(mapsize.y):
		for j in range(mapsize.x):
			vertices[i][j].y = rand_range(height_range.x, height_range.y)
	return vertices

# Generate a completely flat map
func gen_flat(resolution, var value=0):
	var w = resolution.x
	var h = resolution.y
	var vertices = []
	vertices.resize(mapsize.y)
	for j in range(mapsize.y):
		vertices[j] = []
		vertices[j].resize(mapsize.x)
		for i in range(mapsize.x):
			vertices[j][i] = Vector3(i * w + w / 2 - (j % 2) * w / 2, value, j * h)
	return vertices

# Smooth all vertices, based on the following weight distribution:
# 4 for the initial vertex value, 2 for all 4 direct neighbours, 1 for the 4 corner neighbours.
func smooth_terrain(verts):
	for j in range(verts.size()):
		for i in range(verts[j].size()):
			var avg = 4 * verts[j][i].y
			var num = 4
			for x in range(2):
				for y in range(2):
					var mult = 1
					if x == 0 or y == 0:
						mult = 2
					
					if i-x >= 0:
						if j-y >= 0:
							avg += mult * verts[j - y][i - x].y
							num += mult
						if j+y <= verts.size() - 1:
							avg += mult * verts[j + y][i - x].y
							num += mult
					if i+x <= verts[j].size() - 1:
						if j-y >= 0:
							avg += mult * verts[j - y][i + x].y
							num += mult
						if j+y <= verts.size() - 1:
							avg += mult * verts[j + y][i + x].y
							num += mult
			var height = avg / num
			verts[j][i].y = height

func add_to_buffer(buf, tris):
	if buf.has(tris[0]):
		buf[tris[0]].append(tris)
	else:
		buf[tris[0]] = [tris]
	if buf.has(tris[1]):
		buf[tris[1]].append(tris)
	else:
		buf[tris[1]] = [tris]
	if buf.has(tris[2]):
		buf[tris[2]].append(tris)
	else:
		buf[tris[2]] = [tris]

# Create a mesh from a set of vertices.
func create_mesh(vertices = self.vertices, uv_start = self.uv_start, uv_size = self.uv_size, regen=false):
	if not regen:
		dict_normals = {}
	var tri_list = []
	for y in range(vertices.size()):
		var row = vertices[y]
		for x in range(row.size() - 1):
			var alt_col = 1 - (y % 2)
			# Check upper triangle
			if row[x] != null and row[x+1] != null and y < vertices.size()-1 and vertices[y+1][x+alt_col] != null:
				var tris = [row[x], row[x+1], vertices[y+1][x+alt_col]]
				if smooth_normals and not regen:
					add_to_buffer(dict_normals, tris)
					tri_list.append(tris)
				elif smooth_normals and regen:
					add_tri(tris, get_uv(tris, uv_start, uv_size), get_normals(tris, dict_normals))
				else:
					add_tri(tris, get_uv(tris, uv_start, uv_size))
			# Check lower triangle
			if row[x] != null and row[x+1] != null and y > 0 and vertices[y-1][x+alt_col] != null:
				var tris = [row[x], vertices[y-1][x+alt_col], row[x+1],]
				if smooth_normals and not regen:
					add_to_buffer(dict_normals, tris)
					tri_list.append(tris)
				elif smooth_normals and regen:
					add_tri(tris, get_uv(tris, uv_start, uv_size), get_normals(tris, dict_normals))
				else:
					add_tri(tris, get_uv(tris, uv_start, uv_size))
	if smooth_normals and not regen:
		for tris in tri_list:
			add_tri(tris, get_uv(tris, uv_start, uv_size), get_normals(tris, dict_normals))#, get_tangents(tris, dict_normals))
	

func get_uv(tris, uv_start, uv_size):
	var uv = []
	for p in tris:
		var q = Vector2()
		q.x = -(p.x - uv_start.x) / uv_size.x
		q.y = -(p.z - uv_start.y) / uv_size.y
		uv.append(q / uv_scale)
	return uv

func get_normals(tris, buffer):
	var normals = []
	for p in tris:
		if typeof(buffer[p]) == TYPE_ARRAY:
			var normal = Vector3()
			var num = 0
			for t in buffer[p]:
				normal += get_surface_normal(t)
				num += 1
			var this_normal = (normal / num).normalized()
			buffer[p] = this_normal
			normals.append(this_normal)
		else:
			normals.append(buffer[p])
	return normals

func get_tangents(tris, buffer):
	var tangents = []
	for p in tris:
		var n = buffer[p]
		var q = p + n
		var d = -(n.x * q.x + n.y * q.y + n.z * q.z)
		var t = Plane(n, d)
		print(t)
		tangents.append(t)
	return tangents

func get_surface_tangent(tris):
	return Plane(tris[0], tris[1], tris[2])

func get_surface_normal(tri):
	var v = tri[1] - tri[0]
	var w = tri[2] - tri[0]
	var n = w.cross(v)
	return n.normalized()

func fix_seams(chunk, offset):
	var w = mapsize.x - 1
	var h = mapsize.y - 1
	var from
	var to
	
	if chunk.dict_normals.has(vertices[h][w] + offset):
		if chunk.dict_normals.has(vertices[h][0] + offset):
			# Top border
			from = Vector2(0, h)
			to   = Vector2(w+1, h+1)
		else:
			# Left border
			from = Vector2(w, 0)
			to   = Vector2(w+1, h+1)
	else:
		print("Trying to fix seams with a chunk that has no borders with this one, neither to the top nor to the left!")
		return
	
	for j in range(from.y, to.y):
		for i in range(from.x, to.x):
			var p = vertices[j][i]
			var other_normal = chunk.dict_normals[p+offset]
			var my_normal    = dict_normals[p]
			var av = (other_normal + my_normal) / 2
			dict_normals[p] = av
			chunk.dict_normals[p+offset] = av