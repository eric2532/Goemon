extends CanvasLayer
## Native Ed foreground packets, composited after3D and before the game's HUD.
## Scene projection/occlusion remain the packet builder's explicit camera adapter.
const META=&"ed_native_beam_renderer"
const ROOT="res://assets/characters/recovered_leaders/ed/beam/"
const EXTENSION="res://native/ed_psx_renderer/ed_psx_renderer.gdextension"
const PACKETS="res://scripts/recovered_ed_beam_packets.gd"
const COMPOSITE=preload(ROOT+"native_composite.gdshader")
var frame_image:Image
var frame_texture:ImageTexture
var overlay:ColorRect
var composite:ShaderMaterial
var rasterizer:Object
var packet_builder:RefCounted
var configured_size=Vector2i.ZERO
var indices=PackedByteArray()
var palettes=PackedByteArray()
var reported_error=""

static func ensure(owner:Node)->CanvasLayer:
	var viewport=owner.get_viewport()
	if viewport.has_meta(META):
		var existing=viewport.get_meta(META)
		if is_instance_valid(existing):return existing
	var renderer=load("res://scripts/recovered_ed_beam_renderer.gd").new()
	viewport.set_meta(META,renderer)
	viewport.add_child(renderer)
	return renderer

static func native_size(viewport_size:Vector2i)->Vector2i:
	# Keep the native240 scanlines and square pixels while retaining the port's
	# widescreen camera. Original gameplay used320x240 with a320x220 draw clip.
	return Vector2i(maxi(1,ceili(float(viewport_size.x)*240.0/maxi(1,viewport_size.y))),240)

func _ready():
	name="EdNativeBeamRenderer"
	layer=-1
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_priority=100
	composite=ShaderMaterial.new();composite.shader=COMPOSITE
	overlay=ColorRect.new();overlay.name="NativeRGB555Composite"
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.material=composite
	add_child(overlay)
	hide()

func _process(_delta:float):
	render_frame()

func render_frame():
	var viewport=get_viewport()
	var camera=viewport.get_camera_3d()
	if not is_instance_valid(camera):hide();return
	var beams:Array[Node3D]=[]
	for candidate in get_tree().get_nodes_in_group("ed_beams"):
		if not candidate is Node3D or candidate.get_viewport()!=viewport:continue
		if not candidate.is_visible_in_tree() or candidate.is_queued_for_deletion():continue
		if not candidate.has_method("_live") or not candidate._live():continue
		beams.append(candidate)
	if beams.is_empty():hide();return
	if not _prepare_backend():hide();return
	var viewport_size=Vector2i(viewport.get_visible_rect().size)
	if viewport_size.x<=0 or viewport_size.y<=0:hide();return
	var size=native_size(viewport_size)
	if size!=configured_size:
		rasterizer.configure(size.x,size.y,indices,palettes)
		configured_size=size
	var triangles=PackedInt32Array()
	for beam in beams:
		triangles.append_array(packet_builder.build(beam,camera,size))
	if triangles.is_empty():hide();return
	var pixels:PackedByteArray=rasterizer.render(triangles)
	if pixels.size()!=size.x*size.y*4:
		_fail("Native Ed rasterizer returned an invalid frame")
		hide();return
	frame_image=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,pixels)
	if frame_texture==null or frame_texture.get_size()!=Vector2(size):
		frame_texture=ImageTexture.create_from_image(frame_image)
		composite.set_shader_parameter("foreground_rgb5",frame_texture)
	else:
		frame_texture.update(frame_image)
	composite.set_shader_parameter("canvas_linear",viewport.use_hdr_2d)
	overlay.position=Vector2.ZERO;overlay.size=Vector2(viewport_size)
	show()

func _prepare_backend()->bool:
	if rasterizer!=null and packet_builder!=null:return true
	if not ClassDB.class_exists("EdPsxRasterizer") and FileAccess.file_exists(EXTENSION):
		GDExtensionManager.load_extension(EXTENSION)
	if not ClassDB.class_exists("EdPsxRasterizer"):
		_fail("Native Ed rasterizer extension is unavailable")
		return false
	if not ResourceLoader.exists(PACKETS):
		_fail("Native Ed packet assembler is unavailable")
		return false
	indices=FileAccess.get_file_as_bytes(ROOT+"indices.bin")
	palettes=FileAccess.get_file_as_bytes(ROOT+"palettes.bin")
	if indices.size()!=65536 or palettes.size()!=24*16*2:
		_fail("Native Ed source texture or palette bytes are invalid")
		return false
	rasterizer=ClassDB.instantiate("EdPsxRasterizer")
	packet_builder=load(PACKETS).new()
	return true

func _fail(message:String):
	if reported_error!=message:
		reported_error=message
		push_error(message)
