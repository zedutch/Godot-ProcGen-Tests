extends MeshInstance

export(bool) var generate_collision_mesh = false

var st = SurfaceTool.new()

func _init():
	clear()

func clear():
	st.clear()
	mesh = Mesh.new()
	mesh.set_name(get_name().replace(' ', '_').to_lower())

func begin():
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func add_tri(vertices, uv = [], normals = [], tangents = [], smoothing = false):
	for i in range(3):
#		st.add_smooth_group(smoothing)
		if not uv.empty():
			st.add_uv(uv[i])
		if not normals.empty():
			st.add_normal(normals[i])
		if not tangents.empty():
			st.add_tangent(tangents[i])
		st.add_vertex(vertices[i])

func add_quad(vertices, uv = []):
	if not uv.empty():
		st.add_uv(uv[0])
		st.add_vertex(vertices[0])
		st.add_uv(uv[1])
		st.add_vertex(vertices[1])
		st.add_uv(uv[2])
		st.add_vertex(vertices[2])
		st.add_vertex(vertices[2])
		st.add_uv(uv[3])
		st.add_vertex(vertices[3])
		st.add_uv(uv[0])
		st.add_vertex(vertices[0])
	else:
		st.add_vertex(vertices[0])
		st.add_vertex(vertices[1])
		st.add_vertex(vertices[2])
		st.add_vertex(vertices[2])
		st.add_vertex(vertices[3])
		st.add_vertex(vertices[0])

func end(gen_normals = false):
	if gen_normals:
		st.generate_normals()
	st.index()
	st.commit(mesh)
	
	if generate_collision_mesh:
		create_trimesh_collision()