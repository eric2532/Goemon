extends RefCounted
# Reuse six low-poly meadow/bedrock meshes and their exact collision resources.
const OUTLINES=[
	[Vector2(-11,-6),Vector2(-5,-11),Vector2(7,-9),Vector2(12,-2),Vector2(8,8),Vector2(-3,10),Vector2(-12,3)],
	[Vector2(-16,-4),Vector2(-9,-7),Vector2(9,-6),Vector2(16,-1),Vector2(11,5),Vector2(-8,7),Vector2(-15,3)],
	[Vector2(-12,-8),Vector2(-1,-12),Vector2(13,-4),Vector2(9,5),Vector2(3,11),Vector2(-8,8)],
	[Vector2(-12,-9),Vector2(-2,-8),Vector2(5,-12),Vector2(12,-5),Vector2(7,1),Vector2(11,9),Vector2(-1,10),Vector2(-11,5)],
	[Vector2(-13,-7),Vector2(8,-10),Vector2(14,2),Vector2(4,11),Vector2(-8,9)],
	[Vector2(-15,-3),Vector2(-7,-10),Vector2(4,-8),Vector2(11,-3),Vector2(8,4),Vector2(1,9),Vector2(-8,6)]
]
var meshes: Array[ArrayMesh]=[]
var shapes: Array[Shape3D]=[]

func _init():
	for variant in range(OUTLINES.size()):
		var outline=PackedVector2Array(OUTLINES[variant])
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var meadow=Color(["76a667","91ab69","b0b26a"][variant%3])
		var triangles=Geometry2D.triangulate_polygon(outline)
		for t in range(0,triangles.size(),3):
			# Godot's clockwise front faces point upward in the X/Z plane.
			for j in [0,1,2]:
				var p=outline[triangles[t+j]];surface.set_color(meadow);surface.add_vertex(Vector3(p.x,0,p.y))
		var rings=[Vector2(0,1),Vector2(-.65,1.02),Vector2(-2.5,.94),Vector2(-5,.68),Vector2(-8,.25),Vector2(-10,.03)]
		var colors=[Color("a1a379"),Color("8c8871"),Color("657e81"),Color("405b70"),Color("304653")]
		for band in range(rings.size()-1):
			for k in range(outline.size()):
				var a=outline[k];var b=outline[(k+1)%outline.size()]
				var top_a=Vector3(a.x*rings[band].y,rings[band].x,a.y*rings[band].y)
				var top_b=Vector3(b.x*rings[band].y,rings[band].x,b.y*rings[band].y)
				var low_a=Vector3(a.x*rings[band+1].y,rings[band+1].x,a.y*rings[band+1].y)
				var low_b=Vector3(b.x*rings[band+1].y,rings[band+1].x,b.y*rings[band+1].y)
				for p in [top_a,low_a,top_b,top_b,low_a,low_b]:
					surface.set_color(colors[band].lightened(.035*(k%3)));surface.add_vertex(p)
		surface.generate_normals()
		var mesh=surface.commit();meshes.append(mesh)
		var shape=mesh.create_trimesh_shape();shape.backface_collision=true;shapes.append(shape)

func place(parent: Node3D,index: int,point: Vector3,angle: float,size: float)->Node3D:
	var root=Node3D.new();parent.add_child(root);root.position=point;root.rotation.y=angle;root.scale=Vector3.ONE*size
	var material=Geo.mat("ffffff");material.vertex_color_use_as_albedo=true
	var mesh=Geo.mesh(root,meshes[index],Vector3.ZERO,material)
	mesh.visibility_range_end=480;mesh.visibility_range_end_margin=35
	var body=StaticBody3D.new();root.add_child(body)
	var collision=CollisionShape3D.new();collision.shape=shapes[index];body.add_child(collision)
	return root
