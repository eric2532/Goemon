extends SceneTree
## Reproduce the selection art using the actual shipped models and native gear.
## godot --path . --script res://tools/render_roster_selection.gd -- --output=ABS_DIR
## No source mesh, gameplay animation, imported scene or HUD portrait is saved.
const Poses=preload("res://tools/roster_selection_pose.gd")
var output="res://assets/models/characters/selection_portraits"
var evidence=""
var only=""
var view: SubViewport
var stage: Node3D
var manifest: Array=[]
func _initialize():run.call_deferred()
func run():
    if DisplayServer.get_name()=="headless":printerr("Selection art requires a native renderer");quit(1);return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--hero="):only=arg.trim_prefix("--hero=")
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg.begins_with("--evidence="):evidence=arg.trim_prefix("--evidence=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    view=SubViewport.new();view.size=Vector2i(640,720);view.transparent_bg=true;view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;root.add_child(view)
    stage=Node3D.new();view.add_child(stage)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0)
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("cfdfeb");environment.environment.ambient_light_energy=.45
    environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(environment)
    for entry in [[Vector3(-4,6,-6),1.0,Color("ffe2bd")],[Vector3(4,3,-4),.4,Color("c4e6ed")],[Vector3(1,5,4),.75,Color("f1d6a7")]]:
        var light=DirectionalLight3D.new();stage.add_child(light);light.position=entry[0];light.look_at(Vector3(0,1.5,0));light.light_energy=entry[1];light.light_color=entry[2]
    var camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(3.85,2.92,-10);camera.look_at(Vector3(.25,1.65,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.35;camera.current=true
    for index in range(Poses.HEROES.size()):
        if only.is_empty() or only==Poses.HEROES[index]:await render_hero(index+1)
    var report={"size":[640,720],"camera":"shared orthographic three-quarter","poses":"gameplay idle at one second; native bone and equipment drivers","heroes":manifest}
    if not evidence.is_empty():
        DirAccess.make_dir_recursive_absolute(evidence);var file=FileAccess.open(evidence.path_join("selection-render-manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t")+"\n")
    print("ROSTER_SELECTION_RENDER_COMPLETE heroes=",manifest.size());quit()

func render_hero(id: int):
    var hero:String=Poses.HEROES[id-1]
    var actor=Poses.create(id,stage)
    Poses.sample(actor)
    var sk:Skeleton3D=Poses.skeleton(actor)
    for frame in range(5):await process_frame
    await RenderingServer.frame_post_draw
    var image=view.get_texture().get_image();var path=output.path_join(hero+".png");var result=image.save_png(path)
    assert(result==OK,"Cannot save selection portrait "+path)
    var bones=[]
    for bone in sk.get_bone_count():bones.append(var_to_str(sk.get_bone_global_pose(bone)))
    manifest.append({"hero":hero,"file":path,"idle_seconds":1.0,"pose_hash":str(bones).sha256_text()})
    print("SELECTION_RENDERED ",hero," ",path)
    actor.queue_free();await process_frame
