extends Node3D

const BOT_SCRIPT := preload("res://bot.gd")
const DUST2_FLOOR_Y := 11.855
const DUST2_SPAWN_DECK_Y := 31.855
const DUST2_MODEL_SCALE := 75.0 / 16.0
const DUST2_TEXTURE_DEPENDENCIES: Array[Texture2D] = [
	preload("res://assets/dust2/de_dust2_0.png"),
	preload("res://assets/dust2/de_dust2_1.png"),
	preload("res://assets/dust2/de_dust2_2.png"),
	preload("res://assets/dust2/de_dust2_3.png"),
	preload("res://assets/dust2/de_dust2_4.png"),
	preload("res://assets/dust2/de_dust2_5.png"),
	preload("res://assets/dust2/de_dust2_6.png"),
	preload("res://assets/dust2/de_dust2_7.png"),
	preload("res://assets/dust2/de_dust2_8.png"),
	preload("res://assets/dust2/de_dust2_9.png"),
	preload("res://assets/dust2/de_dust2_10.png"),
	preload("res://assets/dust2/de_dust2_11.png"),
	preload("res://assets/dust2/de_dust2_12.png"),
	preload("res://assets/dust2/de_dust2_13.png"),
	preload("res://assets/dust2/de_dust2_14.png"),
	preload("res://assets/dust2/de_dust2_15.png"),
	preload("res://assets/dust2/de_dust2_16.png"),
	preload("res://assets/dust2/de_dust2_17.png"),
	preload("res://assets/dust2/de_dust2_18.png"),
	preload("res://assets/dust2/de_dust2_19.png"),
	preload("res://assets/dust2/de_dust2_20.png"),
	preload("res://assets/dust2/de_dust2_21.png"),
	preload("res://assets/dust2/de_dust2_22.png"),
	preload("res://assets/dust2/de_dust2_23.png"),
	preload("res://assets/dust2/de_dust2_24.png"),
	preload("res://assets/dust2/de_dust2_25.png"),
	preload("res://assets/dust2/de_dust2_26.png"),
	preload("res://assets/dust2/de_dust2_27.png"),
	preload("res://assets/dust2/de_dust2_28.png"),
	preload("res://assets/dust2/de_dust2_29.png"),
	preload("res://assets/dust2/de_dust2_30.png"),
	preload("res://assets/dust2/de_dust2_31.png"),
	preload("res://assets/dust2/de_dust2_32.png"),
	preload("res://assets/dust2/de_dust2_33.png"),
]
const RADAR_IMAGE_SIZE := 768.0
const RADAR_IMAGE_PADDING := 18.0
const RADAR_ZOOM := 1.65
const DUST2_MAP_MIN_X := -140.0
const DUST2_MAP_MAX_X := 140.0
const DUST2_MAP_MIN_Z := -166.0
const DUST2_MAP_MAX_Z := 166.0
var player: CharacterBody3D
var ui: CanvasLayer
var menu: Control
var hud: Control
var mode := "PRACTICE"
var online_match := false
var online_team := "t"
var online_peer: WebSocketPeer
var online_url_input: LineEdit
var online_room_input: LineEdit
var online_status_label: Label
var online_join_sent := false
var online_connect_timer := 0.0
var online_send_timer := 0.0
var online_player_id := ""
var online_player_count := 1
var online_players: Dictionary = {}
var map_name := "DUST II"
var kills := 0
var deaths := 0
var assists := 0
var damage_dealt := 0
var headshot_kills := 0
var damage_by_bot: Dictionary = {}
var health := 100
var match_active := false
var pause_panel: PanelContainer
var sensitivity_label: Label
var countdown_label: Label
var buy_panel: PanelContainer
var damage_cooldown := 0.0
var rng := RandomNumberGenerator.new()
var bot_nodes: Array[CharacterBody3D] = []
var status_label: Label
var ammo_label: Label
var score_label: Label
var kill_label: Label
var killfeed: VBoxContainer
var radar: Label
var radar_panel: PanelContainer
var radar_canvas: Control
var radar_map_layer: Control
var radar_background: TextureRect
var radar_marks: Array[ColorRect] = []
var radar_player_arrow: Polygon2D
var spotted_enemies: Dictionary = {}
var team_alive_label: Label
var enemy_alive_label: Label
var crosshair: Label
var scope_reticle: Label
var fps_label: Label
var scoreboard_panel: PanelContainer
var scoreboard_rows: VBoxContainer
var bot_stats: Dictionary = {}
var damage_contributors: Dictionary = {}
var scoreboard_signature := ""
var round_live := false
var round_t_wins := 0
var round_ct_wins := 0
var round_resolving := false
var money := 800
var loss_streak := 0
var round_time_left := 115.0
var grenade_kills := 0
var bomb_carried := true
var bomb_planted := false
var bomb_time_left := 0.0
var bomb_position := Vector3.ZERO
var bomb_site_center := Vector3(80.0, DUST2_FLOOR_Y, -101.0)
var chat_log: RichTextLabel
var chat_input: LineEdit
var armor := 0
var armor_helmet := false
var bought_this_round := 0
var grenade_purchases_this_round := 0
var planted_this_round := false
var grenade_clouds: Array[Node3D] = []
var buy_phase := false
var site_marker: MeshInstance3D
var bomb_node: Node3D
var flash_overlay: ColorRect
var last_kill_reward := 300
var bomb_explosion_wins := false
var bomb_last_callout := 30
var bot_styles := ["RUSHER", "ANCHOR", "FLANKER", "SCOUT", "DUELIST", "GUARD", "BREACHER", "HUNTER", "TACTICIAN", "SPRINTER", "SENTINEL", "STRIKER"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_world()
	player = get_node("Player") as CharacterBody3D
	player.scale = Vector3.ONE * 1.5
	(player.get_node("CollisionShape3D") as CollisionShape3D).disabled = false
	player.set_physics_process(false)
	player.connect("fired", Callable(self, "_on_player_fired"))
	player.connect("reloaded", Callable(self, "_on_reloaded"))
	player.connect("scope_changed", Callable(self, "_on_scope_changed"))
	player.connect("grenade_thrown", Callable(self, "_on_player_grenade_thrown"))
	_load_sensitivity()
	_build_ui()
	_show_menu()

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.36, 0.54)
	sky_mat.sky_horizon_color = Color(0.91, 0.72, 0.51)
	sky_mat.ground_bottom_color = Color(0.19, 0.15, 0.11)
	sky_mat.ground_horizon_color = Color(0.55, 0.41, 0.28)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ambient_light_energy = 0.28
	env.tonemap_exposure = 0.66
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_color = Color("ffe0b0")
	light.light_energy = 0.46
	light.shadow_enabled = true
	add_child(light)
	_build_map()

func _build_map() -> void:
	# GLB materials reference extracted texture files. Keep these explicit
	# dependencies so Godot's web exporter includes them in the PCK as well.
	assert(DUST2_TEXTURE_DEPENDENCIES.size() == 34)
	for child in get_children():
		if child.is_in_group("map_geometry"):
			child.queue_free()
	var map_body := StaticBody3D.new()
	map_body.name = "Dust II Detailed GLB Map and Collision"
	map_body.add_to_group("map_geometry")
	var map_scene := load("res://assets/dust2/de_dust2.glb") as PackedScene
	if map_scene == null:
		push_error("Detailed Dust II GLB did not import as a PackedScene. Open the project in Godot to import the map asset.")
		add_child(map_body)
		return
	var map_visual := map_scene.instantiate() as Node3D
	map_visual.name = "Detailed Textured Dust II Model"
	# Godot imports this GLB at 1/75 scale. Compensate for the importer and
	# fit the detailed model to the radar/world coordinate system.
	map_visual.scale = Vector3.ONE * DUST2_MODEL_SCALE
	map_visual.position = Vector3.ZERO
	map_body.add_child(map_visual)
	add_child(map_body)
	# Keep the GLB's authored textures and use its exact triangles for collision.
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_map_meshes(map_visual, mesh_nodes)
	var map_bounds := AABB()
	var has_map_bounds := false
	for mesh_node in mesh_nodes:
		if mesh_node.mesh == null:
			continue
		var mesh_bounds := _transformed_mesh_bounds(mesh_node)
		map_bounds = mesh_bounds if not has_map_bounds else map_bounds.merge(mesh_bounds)
		has_map_bounds = true
	if has_map_bounds:
		map_visual.position += Vector3(
			DUST2_MAP_MIN_X - map_bounds.position.x,
			DUST2_FLOOR_Y - map_bounds.position.y,
			DUST2_MAP_MIN_Z - map_bounds.position.z
		)
	for mesh_node in mesh_nodes:
		if mesh_node.mesh == null:
			continue
		var map_shape := mesh_node.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		if map_shape == null:
			continue
		map_shape.backface_collision = true
		var map_collision := CollisionShape3D.new()
		map_collision.name = "Collision - " + mesh_node.name
		map_collision.shape = map_shape
		map_body.add_child(map_collision)
		map_collision.global_transform = mesh_node.global_transform

func _collect_map_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_map_meshes(child, output)

func _transformed_mesh_bounds(mesh_node: MeshInstance3D) -> AABB:
	var source_bounds := mesh_node.mesh.get_aabb()
	var first_point := mesh_node.global_transform * source_bounds.position
	var minimum := first_point
	var maximum := first_point
	for x_corner in [0.0, 1.0]:
		for y_corner in [0.0, 1.0]:
			for z_corner in [0.0, 1.0]:
				var local_point := source_bounds.position + Vector3(
					source_bounds.size.x * x_corner,
					source_bounds.size.y * y_corner,
					source_bounds.size.z * z_corner
				)
				var world_point := mesh_node.global_transform * local_point
				minimum = Vector3(minf(minimum.x, world_point.x), minf(minimum.y, world_point.y), minf(minimum.z, world_point.z))
				maximum = Vector3(maxf(maximum.x, world_point.x), maxf(maximum.y, world_point.y), maxf(maximum.z, world_point.z))
	return AABB(minimum, maximum - minimum)
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(hud)
	var top := _label("Xd  |  PREMIER PRACTICE", 20, Color("e3b562"))
	top.position = Vector2(30, 22)
	hud.add_child(top)
	score_label = _label("0   :   0", 24, Color.WHITE)
	score_label.anchor_left = 0.5
	score_label.anchor_right = 0.5
	score_label.position = Vector2(-200, 24)
	score_label.custom_minimum_size = Vector2(400, 34)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(score_label)
	team_alive_label = _label("● ● ● ● ●", 20, Color("78d8c5"))
	team_alive_label.anchor_left = 0.5
	team_alive_label.anchor_right = 0.5
	team_alive_label.position = Vector2(-420, 27)
	team_alive_label.custom_minimum_size = Vector2(190, 28)
	team_alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(team_alive_label)
	enemy_alive_label = _label("● ● ● ● ●", 20, Color("e58a72"))
	enemy_alive_label.anchor_left = 0.5
	enemy_alive_label.anchor_right = 0.5
	enemy_alive_label.position = Vector2(230, 27)
	enemy_alive_label.custom_minimum_size = Vector2(190, 28)
	enemy_alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(enemy_alive_label)
	ammo_label = _label("AK-STYLE RIFLE     30 / 90", 17, Color("eef2f3"))
	ammo_label.anchor_left = 1.0
	ammo_label.anchor_right = 1.0
	ammo_label.position = Vector2(-290, 24)
	hud.add_child(ammo_label)
	status_label = _label("100 HP   •   $800", 18, Color("dfe8df"))
	status_label.position = Vector2(30, 64)
	hud.add_child(status_label)
	fps_label = _label("FPS: --", 16, Color("9fe2b5"))
	fps_label.anchor_left = 1.0
	fps_label.anchor_right = 1.0
	fps_label.position = Vector2(-115, 62)
	hud.add_child(fps_label)
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.anchor_left = 0.5
	scoreboard_panel.anchor_right = 0.5
	scoreboard_panel.anchor_top = 0.5
	scoreboard_panel.anchor_bottom = 0.5
	scoreboard_panel.position = Vector2(-520, -320)
	scoreboard_panel.custom_minimum_size = Vector2(1040, 640)
	hud.add_child(scoreboard_panel)
	var scoreboard_box := VBoxContainer.new()
	scoreboard_box.add_theme_constant_override("separation", 12)
	scoreboard_panel.add_child(scoreboard_box)
	var scoreboard_title := _label("MATCH SCOREBOARD   /   TAB TO CLOSE", 22, Color("e3b562"))
	scoreboard_box.add_child(scoreboard_title)
	var scoreboard_columns := _label("PLAYER                         K      D      A       SCORE       DAMAGE       HS%", 16, Color("aebdc0"))
	scoreboard_box.add_child(scoreboard_columns)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scoreboard_box.add_child(scroll)
	scoreboard_rows = VBoxContainer.new()
	scoreboard_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scoreboard_rows)
	scoreboard_panel.hide()
	kill_label = _label("", 25, Color("ffc85a"))
	kill_label.anchor_left = 0.5
	kill_label.anchor_right = 0.5
	kill_label.anchor_top = 0.33
	kill_label.anchor_bottom = 0.33
	kill_label.position = Vector2(-180, 0)
	kill_label.custom_minimum_size = Vector2(360, 50)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(kill_label)
	killfeed = VBoxContainer.new()
	killfeed.anchor_left = 1.0
	killfeed.anchor_right = 1.0
	killfeed.position = Vector2(-470, 104)
	killfeed.custom_minimum_size = Vector2(440, 0)
	killfeed.add_theme_constant_override("separation", 5)
	killfeed.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(killfeed)
	countdown_label = _label("", 60, Color("f2c76b"))
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_top = 0.5
	countdown_label.anchor_bottom = 0.5
	countdown_label.position = Vector2(-100, -90)
	countdown_label.custom_minimum_size = Vector2(200, 100)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.hide()
	hud.add_child(countdown_label)
	crosshair = _label("+", 24, Color("f4f1e8"))
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.position = Vector2(-7, -17)
	hud.add_child(crosshair)
	scope_reticle = _label("⊕", 54, Color("e9eee9"))
	scope_reticle.anchor_left = 0.5
	scope_reticle.anchor_right = 0.5
	scope_reticle.anchor_top = 0.5
	scope_reticle.anchor_bottom = 0.5
	scope_reticle.position = Vector2(-26, -39)
	scope_reticle.hide()
	hud.add_child(scope_reticle)
	var hint := _label("WASD Move    SHIFT Walk    CTRL Crouch    SPACE Jump    1 Primary    2 Pistol    3 Knife    4 Utility    5 C4    RMB Scope AWP    E Plant    B Buy    Y Chat", 14, Color("d4d6d4"))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.position = Vector2(30, -34)
	hud.add_child(hint)
	_build_buy_menu()
	_build_chat()
	_build_pause_menu()
	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.z_index = 100
	hud.add_child(flash_overlay)
	_build_minimap()
	hud.hide()

func _build_minimap() -> void:
	radar_panel = PanelContainer.new()
	radar_panel.position = Vector2(24, 58)
	radar_panel.custom_minimum_size = Vector2(158, 158)
	hud.add_child(radar_panel)
	radar_canvas = Control.new()
	radar_canvas.custom_minimum_size = Vector2(148, 148)
	radar_canvas.clip_contents = true
	radar_panel.add_child(radar_canvas)
	radar_map_layer = Control.new()
	radar_map_layer.name = "Rotating centered radar map"
	radar_map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radar_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_canvas.add_child(radar_map_layer)
	radar_background = TextureRect.new()
	radar_background.name = "Dust II radar artwork"
	radar_background.texture = load("res://assets/dust2/dust2_radar.png") as Texture2D
	radar_background.stretch_mode = TextureRect.STRETCH_SCALE
	radar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_map_layer.add_child(radar_background)
	for i in range(10):
		var mark := ColorRect.new()
		mark.size = Vector2(9, 9)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.hide()
		radar_map_layer.add_child(mark)
		radar_marks.append(mark)
	# Directional player marker makes the radar useful while moving through lanes.
	var arrow_backing := Polygon2D.new()
	arrow_backing.name = "Player marker outline"
	arrow_backing.polygon = PackedVector2Array([Vector2(0, -9), Vector2(7, 8), Vector2(0, 5), Vector2(-7, 8)])
	arrow_backing.color = Color("172321")
	arrow_backing.visible = false
	radar_canvas.add_child(arrow_backing)
	var arrow_core := Polygon2D.new()
	arrow_core.polygon = PackedVector2Array([Vector2(0, -6), Vector2(4.5, 6), Vector2(0, 3.5), Vector2(-4.5, 6)])
	arrow_core.color = Color("73e6c8")
	arrow_backing.add_child(arrow_core)
	radar_player_arrow = arrow_backing

func _build_buy_menu() -> void:
	buy_panel = PanelContainer.new()
	buy_panel.anchor_left = 0.5
	buy_panel.anchor_right = 0.5
	buy_panel.anchor_top = 0.5
	buy_panel.anchor_bottom = 0.5
	buy_panel.position = Vector2(-320, -300)
	buy_panel.custom_minimum_size = Vector2(640, 600)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	buy_panel.add_child(vb)
	var title := _label("  ARMORY   /   B TO CLOSE", 22, Color("e3b562"))
	vb.add_child(title)
	for text in ["1  AK-47  —  $2700", "2  Glock-18  —  $200", "3  USP-S  —  $200", "4  AWP  —  $4750", "5  Kevlar + Helmet  —  $1000", "6  HE Grenade  —  $300", "7  Smoke Grenade  —  $300", "8  Flashbang  —  $200", "9  Molotov  —  $400"]:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size.y = 46
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_buy_item.bind(text))
		vb.add_child(b)
	buy_panel.hide()
	hud.add_child(buy_panel)

func _build_chat() -> void:
	chat_log = RichTextLabel.new()
	chat_log.anchor_top = 1.0
	chat_log.anchor_bottom = 1.0
	chat_log.position = Vector2(30, -245)
	chat_log.custom_minimum_size = Vector2(700, 175)
	chat_log.bbcode_enabled = true
	chat_log.scroll_active = false
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.add_theme_font_size_override("normal_font_size", 16)
	hud.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.anchor_top = 1.0
	chat_input.anchor_bottom = 1.0
	chat_input.position = Vector2(30, -62)
	chat_input.custom_minimum_size = Vector2(700, 38)
	chat_input.placeholder_text = "Team chat — Enter to send, Esc to cancel"
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.hide()
	hud.add_child(chat_input)

func _build_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.anchor_left = 0.5
	pause_panel.anchor_right = 0.5
	pause_panel.anchor_top = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.position = Vector2(-230, -155)
	pause_panel.custom_minimum_size = Vector2(460, 380)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	pause_panel.add_child(layout)
	var title := _label("MATCH PAUSED", 28, Color("e3b562"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	sensitivity_label = _label("MOUSE SENSITIVITY   %.4f" % float(player.get("mouse_sensitivity")), 16, Color("dfe8df"))
	layout.add_child(sensitivity_label)
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = 0.0005
	sensitivity_slider.max_value = 0.006
	sensitivity_slider.step = 0.0001
	sensitivity_slider.value = float(player.get("mouse_sensitivity"))
	sensitivity_slider.custom_minimum_size = Vector2(380, 26)
	sensitivity_slider.value_changed.connect(_set_sensitivity)
	layout.add_child(sensitivity_slider)
	var resume := Button.new()
	resume.text = "RESUME MATCH"
	resume.custom_minimum_size.y = 48
	resume.pressed.connect(_resume_match)
	layout.add_child(resume)
	var main_menu := Button.new()
	main_menu.text = "RETURN TO MAIN MENU"
	main_menu.custom_minimum_size.y = 48
	main_menu.pressed.connect(_return_to_main_menu)
	layout.add_child(main_menu)
	pause_panel.hide()
	hud.add_child(pause_panel)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _load_sensitivity() -> void:
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		player.set("mouse_sensitivity", float(settings.get_value("controls", "sensitivity", 0.0022)))

func _set_sensitivity(value: float) -> void:
	if not is_instance_valid(player): return
	player.set("mouse_sensitivity", value)
	if is_instance_valid(sensitivity_label):
		sensitivity_label.text = "MOUSE SENSITIVITY   %.4f" % value
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("controls", "sensitivity", value)
	settings.save("user://settings.cfg")

func _show_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.055, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var panel := VBoxContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.position = Vector2(-300, -340)
	panel.custom_minimum_size = Vector2(600, 680)
	panel.add_theme_constant_override("separation", 16)
	menu.add_child(panel)
	var title := _label("COUNTER OPS", 42, Color("e7b85f"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var sub := _label("TACTICAL TRAINING     /     BUILD 01", 15, Color("bbc4c5"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)
	var mode_picker := OptionButton.new()
	mode_picker.add_item("PRACTICE  •  Solo bot drills")
	mode_picker.add_item("5v5  •  5 allies vs 5 bots")
	mode_picker.add_item("DEATHMATCH  •  Free for all vs bots")
	mode_picker.add_item("ONLINE 5v5  •  Matchmaking room")
	mode_picker.add_item("ONLINE DEATHMATCH  •  Matchmaking room")
	mode_picker.custom_minimum_size.y = 48
	mode_picker.add_theme_font_size_override("font_size", 17)
	panel.add_child(mode_picker)
	var map_picker := OptionButton.new()
	map_picker.add_item("DUST II")
	map_picker.custom_minimum_size.y = 48
	map_picker.add_theme_font_size_override("font_size", 17)
	panel.add_child(map_picker)
	online_url_input = LineEdit.new()
	online_url_input.placeholder_text = "WebSocket server: wss://counter-ops-match-server.onrender.com/ws"
	online_url_input.text = "wss://counter-ops-match-server.onrender.com/ws"
	online_url_input.custom_minimum_size.y = 42
	panel.add_child(online_url_input)
	online_room_input = LineEdit.new()
	online_room_input.placeholder_text = "Room code (same code joins the same match)"
	online_room_input.text = "public"
	online_room_input.custom_minimum_size.y = 42
	panel.add_child(online_room_input)
	online_status_label = _label("ONLINE MATCHES NEED THE MATCH SERVER TO BE DEPLOYED", 12, Color("9ba9a9"))
	online_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(online_status_label)
	var start := Button.new()
	start.text = "PLAY  →"
	start.custom_minimum_size.y = 58
	start.add_theme_font_size_override("font_size", 21)
	start.pressed.connect(_start_match.bind(mode_picker, map_picker))
	panel.add_child(start)
	var notes := _label("WASD move   •   SHIFT walk   •   CTRL crouch   •   SPACE bhop\n1 primary   •   2 pistol   •   3 knife   •   4 cycle utility   •   5 C4   •   RMB scope AWP   •   R reload   •   B buy", 15, Color("c1cacc"))
	notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(notes)
	var resolution := _label("1920 × 1080  |  RESIZABLE WINDOW", 13, Color("7f9297"))
	resolution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(resolution)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_match(mode_picker: OptionButton, map_picker: OptionButton) -> void:
	var selected_mode := mode_picker.selected
	online_match = selected_mode >= 3
	if online_match:
		var socket_url := online_url_input.text.strip_edges()
		if not socket_url.begins_with("wss://") and not socket_url.begins_with("ws://"):
			online_status_label.text = "ENTER A VALID ws:// OR wss:// MATCH SERVER URL"
			online_status_label.add_theme_color_override("font_color", Color("ff8d72"))
			return
		if not _connect_online(socket_url, "5v5" if selected_mode == 3 else "deathmatch", online_room_input.text.strip_edges()): return
	else:
		_disconnect_online()
	mode = "PRACTICE" if selected_mode == 0 else "5V5" if selected_mode == 1 or selected_mode == 3 else "DEATHMATCH"
	map_name = "DUST II"
	money = 800
	loss_streak = 0
	bought_this_round = 0
	grenade_purchases_this_round = 0
	armor = 0
	armor_helmet = false
	bomb_carried = true
	bomb_planted = false
	bomb_explosion_wins = false
	bomb_last_callout = 30
	planted_this_round = false
	player.set("grenades", {"he": 0, "smoke": 0, "flash": 0, "molotov": 0})
	chat_log.clear()
	round_t_wins = 0
	round_ct_wins = 0
	round_resolving = false
	damage_cooldown = 0.0
	menu.queue_free()
	menu = null
	var player_side := online_team if online_match and mode == "5V5" else "t" if mode == "5V5" else "any"
	player.global_position = _random_spawn_position(true, player_side)
	(player.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", false)
	player.rotation = Vector3(0, 0.45, 0)
	player.velocity = Vector3.ZERO
	player.set("primary_weapon", "" if mode == "5V5" else "rifle")
	player.set("pistol_model", "glock" if mode == "5V5" else "usp")
	if mode == "5V5":
		player.set("pistol_ammo", 20)
		player.set("pistol_reserve", 120)
	player.set("has_c4", mode == "5V5" and player_side == "t")
	player.set("reloading", false)
	player.set("movement_locked", mode == "5V5")
	if mode == "5V5":
		player.call("equip_pistol", "glock")
		_chat_message("LOADOUT", "T side issued Glock-18. Starting balance $800.")
	else:
		player.call("equip_primary")
	health = 100
	kills = 0
	deaths = 0
	assists = 0
	damage_dealt = 0
	headshot_kills = 0
	damage_by_bot.clear()
	bot_stats.clear()
	damage_contributors.clear()
	spotted_enemies.clear()
	round_live = mode != "5V5"
	buy_phase = mode == "5V5"
	if mode == "5V5": _create_bomb_site_marker()
	bot_styles.shuffle()
	_spawn_bots()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match_active = true
	_refresh_hud()
	if online_match: _chat_message("ONLINE", "Connecting to room %s…" % str(get_meta("online_room_name", "public")).to_upper())
	if mode == "5V5":
		_run_round_countdown()
	else:
		round_live = true
		player.set("movement_locked", false)
		player.set_physics_process(true)
		for bot in bot_nodes: bot.set_physics_process(true)

func _spawn_bots() -> void:
	for bot in bot_nodes:
		bot.queue_free()
	bot_nodes.clear()
	var count := 0 if online_match and (mode == "DEATHMATCH" or online_player_count >= 2) else 5 if mode == "PRACTICE" or mode == "5V5" else 12
	for i in range(count):
		var bot: CharacterBody3D = CharacterBody3D.new()
		bot.set_script(BOT_SCRIPT)
		bot.name = "Rival_%02d" % (i + 1)
		var enemy_side := "ct" if not online_match or online_team == "t" else "t"
		bot.position = _random_spawn_position(false, enemy_side if mode == "5V5" else "any")
		bot.add_to_group("bots")
		bot.add_to_group("bot_heads")
		bot.set_physics_process(false)
		add_child(bot)
		bot.call("setup", player, self, false, bot_styles[i % bot_styles.size()])
		_register_bot_stats(bot, "RIVAL %02d  /  %s" % [i + 1, bot_styles[i % bot_styles.size()]])
		bot_nodes.append(bot)
	if mode == "5V5":
		for i in range(4):
			var ally: CharacterBody3D = CharacterBody3D.new()
			ally.set_script(BOT_SCRIPT)
			ally.position = _random_spawn_position(false, online_team if online_match else "t")
			ally.add_to_group("allies")
			ally.set_physics_process(false)
			add_child(ally)
			ally.call("setup", player, self, true, bot_styles[(i + 5) % bot_styles.size()])
			_register_bot_stats(ally, "ALLY %02d  /  %s" % [i + 1, bot_styles[(i + 5) % bot_styles.size()]])
			bot_nodes.append(ally)

func _run_round_countdown() -> void:
	round_live = false
	buy_phase = true
	player.set("movement_locked", true)
	player.set_physics_process(false)
	countdown_label.show()
	_chat_message("ROUND", "Buy phase: 15 seconds. Press B to buy; Y opens chat.")
	for count in range(15, 0, -1):
		if not match_active: return
		countdown_label.text = str(count)
		await get_tree().create_timer(1.0).timeout
	if not match_active: return
	buy_phase = false
	buy_panel.hide()
	countdown_label.hide()
	round_live = true
	round_time_left = 115.0
	player.set("movement_locked", false)
	player.set_physics_process(true)
	for bot in bot_nodes:
		if is_instance_valid(bot): bot.set_physics_process(true)
	_chat_message("ROUND", "Round live — 1:55. Plant C4 with E inside the marked site.")

func _check_5v5_round_end() -> void:
	if mode != "5V5" or round_resolving or not match_active: return
	if bomb_planted: return
	var t_alive := health > 0 and (not online_match or online_team == "t")
	var ct_alive := health > 0 and online_match and online_team == "ct"
	for entry in online_players.values():
		if not bool(entry.get("alive", true)): continue
		if str(entry.get("team", "")) == "t": t_alive = true
		elif str(entry.get("team", "")) == "ct": ct_alive = true
	for bot in bot_nodes:
		if not is_instance_valid(bot) or int(bot.get("hp")) <= 0: continue
		if bot.is_in_group("allies"):
			if not online_match or online_team == "t": t_alive = true
			else: ct_alive = true
		elif bot.is_in_group("bots"):
			if not online_match or online_team == "t": ct_alive = true
			else: t_alive = true
	if not ct_alive:
		_finish_5v5_round("T")
	elif not t_alive:
		_finish_5v5_round("CT")

func _finish_5v5_round(winner: String) -> void:
	if round_resolving or mode != "5V5" or not match_active: return
	round_resolving = true
	round_live = false
	buy_phase = false
	_settle_round_economy(winner)
	player.set("movement_locked", true)
	player.set_physics_process(false)
	for bot in bot_nodes:
		if is_instance_valid(bot):
			bot.set_physics_process(false)
			bot.velocity = Vector3.ZERO
	if winner == "T": round_t_wins += 1
	else: round_ct_wins += 1
	_refresh_hud()
	countdown_label.show()
	var match_tied := round_t_wins == 12 and round_ct_wins == 12
	var match_won := round_t_wins >= 13 or round_ct_wins >= 13
	var player_won_round := winner == (online_team if online_match else "t")
	if match_tied or match_won:
		if match_tied:
			countdown_label.text = "MATCH TIED  12 — 12"
		else:
			countdown_label.text = "MATCH WON" if player_won_round else "MATCH LOST"
		await get_tree().create_timer(5.0).timeout
		if match_active: _return_to_main_menu()
		return
	countdown_label.text = "ROUND WON" if player_won_round else "ROUND LOST"
	await get_tree().create_timer(2.5).timeout
	if match_active: _start_next_5v5_round()

func _settle_round_economy(winner: String) -> void:
	var player_side := online_team if online_match else "t"
	if winner.to_lower() == player_side:
		var reward := 3500 if bomb_explosion_wins else 3250
		_add_money(reward, "Team round victory")
		loss_streak = maxi(0, loss_streak - 1)
		_chat_message("ROUND", "Your team wins. Next loss bonus: $%d." % (1400 + mini(4, loss_streak) * 500))
	else:
		loss_streak = mini(5, loss_streak + 1)
		var loss_reward := 1400 + mini(4, loss_streak - 1) * 500
		_add_money(loss_reward, "Team loss bonus tier %d" % loss_streak)
		if planted_this_round and player_side == "t": _add_money(800, "Bomb-plant loss bonus")
		_chat_message("ROUND", "Your team lost. Loss bonus is $%d next round." % (1400 + mini(4, loss_streak) * 500))
	bomb_explosion_wins = false

func _create_bomb_site_marker() -> void:
	if is_instance_valid(site_marker): return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(bomb_site_center.x, 48.0, bomb_site_center.z), Vector3(bomb_site_center.x, -1.0, bomb_site_center.z))
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and Vector3(hit["normal"]).y > 0.75:
		bomb_site_center = hit["position"]
	else:
		bomb_site_center.y = DUST2_FLOOR_Y
	site_marker = MeshInstance3D.new()
	site_marker.name = "A Site Ground Marker"
	var ring := TorusMesh.new()
	ring.inner_radius = 5.7
	ring.outer_radius = 6.0
	site_marker.mesh = ring
	site_marker.position = bomb_site_center + Vector3.UP * 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.66, 0.16, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	site_marker.material_override = mat
	add_child(site_marker)
	var title := Label3D.new()
	title.text = "A  /  BOMB PLANT ZONE"
	title.position = bomb_site_center + Vector3(0, 0.35, 0)
	title.font_size = 34
	title.pixel_size = 0.012
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color("ffd17a")
	add_child(title)

func _try_bomb_interaction() -> void:
	if mode != "5V5" or not round_live or health <= 0: return
	var player_flat := Vector2(player.global_position.x, player.global_position.z)
	var site_flat := Vector2(bomb_site_center.x, bomb_site_center.z)
	if bomb_carried:
		if player_flat.distance_to(site_flat) > 6.0:
			_chat_message("C4", "Move into the marked A site to plant.")
			return
		bomb_carried = false
		player.set("has_c4", false)
		player.call("equip_primary")
		bomb_planted = true
		planted_this_round = true
		bomb_time_left = 30.0
		bomb_last_callout = 30
		bomb_position = bomb_site_center + Vector3.UP * 0.18
		_create_planted_bomb()
		_add_money(300, "Bomb planted")
		_chat_message("C4", "PLANTED at A. Detonation in 30 seconds.")
		return
	if bomb_planted and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(bomb_position.x, bomb_position.z)) < 3.0:
		_chat_message("C4", "Hold position near the device to defuse. (Player is on T side.)")
	else:
		_chat_message("C4", "You are not carrying the C4.")

func _create_planted_bomb() -> void:
	if is_instance_valid(bomb_node): bomb_node.queue_free()
	bomb_node = Node3D.new()
	bomb_node.name = "Planted C4"
	bomb_node.position = bomb_position
	add_child(bomb_node)
	var casing := MeshInstance3D.new()
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.38, 0.14, 0.26)
	casing.mesh = case_mesh
	var case_mat := StandardMaterial3D.new()
	case_mat.albedo_color = Color("353b37")
	case_mat.metallic = 0.46
	case_mat.roughness = 0.42
	casing.material_override = case_mat
	bomb_node.add_child(casing)
	for x in [-0.12, 0.0, 0.12]:
		var key := MeshInstance3D.new()
		var key_mesh := BoxMesh.new()
		key_mesh.size = Vector3(0.045, 0.012, 0.035)
		key.mesh = key_mesh
		key.position = Vector3(x, 0.078, -0.04)
		key.material_override = case_mat
		bomb_node.add_child(key)
	var led := MeshInstance3D.new()
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.028
	led_mesh.height = 0.04
	led.mesh = led_mesh
	led.name = "C4 LED"
	led.position = Vector3(0.12, 0.086, 0.07)
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color("ff3824")
	led_mat.emission_enabled = true
	led_mat.emission = Color("ff1608")
	led.material_override = led_mat
	bomb_node.add_child(led)
	var display := Label3D.new()
	display.name = "Bomb Timer Display"
	display.position = Vector3(0, 0.17, 0)
	display.font_size = 34
	display.pixel_size = 0.006
	display.modulate = Color("ff6551")
	bomb_node.add_child(display)

func _update_round_objectives(delta: float) -> void:
	if not round_live or mode != "5V5": return
	if bomb_planted:
		bomb_time_left = maxf(0.0, bomb_time_left - delta)
		if is_instance_valid(bomb_node):
			var display := bomb_node.get_node_or_null("Bomb Timer Display") as Label3D
			if display: display.text = "%02d" % ceili(bomb_time_left)
			var led := bomb_node.get_node_or_null("C4 LED") as MeshInstance3D
			if led:
				var led_material := led.material_override as StandardMaterial3D
				if led_material: led_material.emission_energy_multiplier = 1.0 + fposmod(Time.get_ticks_msec() / 1000.0, 1.0) * 3.0
		if bomb_time_left <= 20.0 and bomb_last_callout > 20: _call_bomb_timer(20)
		elif bomb_time_left <= 10.0 and bomb_last_callout > 10: _call_bomb_timer(10)
		elif bomb_time_left <= 5.0 and bomb_last_callout > 5: _call_bomb_timer(5)
		if bomb_time_left <= 0.0 and not round_resolving:
			bomb_explosion_wins = true
			_create_bomb_explosion()
			_chat_message("C4", "Bomb detonated. T side wins the round.")
			_finish_5v5_round("T")
	elif round_time_left > 0.0:
		round_time_left = maxf(0.0, round_time_left - delta)
		if round_time_left <= 0.0:
			_chat_message("ROUND", "Time expired without a plant. CT side wins.")
			_finish_5v5_round("CT")

func _call_bomb_timer(seconds: int) -> void:
	bomb_last_callout = seconds
	_chat_message("C4", "%d seconds to detonation." % seconds)

func bot_defused_bomb(defuser: Node3D) -> void:
	if not bomb_planted or round_resolving: return
	bomb_planted = false
	bomb_time_left = 0.0
	_chat_message("C4", "%s defused the bomb." % _bot_display_name(defuser))
	_finish_5v5_round("CT")

func _create_bomb_explosion() -> void:
	var blast := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	blast.mesh = mesh
	blast.position = bomb_position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.31, 0.04, 0.8)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.14, 0.01)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast.material_override = material
	add_child(blast)
	var light := OmniLight3D.new()
	light.light_color = Color("ff6b23")
	light.light_energy = 7.0
	light.omni_range = 18.0
	blast.add_child(light)
	var tween := create_tween()
	tween.tween_property(blast, "scale", Vector3.ONE * 9.0, 0.45)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(blast.queue_free)

func _on_player_grenade_thrown(kind: String, origin: Vector3, direction: Vector3) -> void:
	last_kill_reward = 300
	var projectile := RigidBody3D.new()
	projectile.name = "%s Grenade" % kind.capitalize()
	projectile.mass = 0.45
	projectile.gravity_scale = 1.0
	projectile.linear_damp = 0.12
	projectile.angular_damp = 0.25
	projectile.position = origin
	projectile.collision_layer = 1
	projectile.collision_mask = 1
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.13
	collision.shape = sphere
	projectile.add_child(collision)
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.13
	shell_mesh.height = 0.29
	shell.mesh = shell_mesh
	var shell_mat := StandardMaterial3D.new()
	var shell_colors := {"he": Color("334b35"), "smoke": Color("56665a"), "flash": Color("b3a777"), "molotov": Color("79462f")}
	shell_mat.albedo_color = shell_colors.get(kind, Color("334b35"))
	shell_mat.metallic = 0.3
	shell_mat.roughness = 0.54
	shell.material_override = shell_mat
	projectile.add_child(shell)
	for rib_index in range(4):
		var rib := MeshInstance3D.new()
		var rib_mesh := TorusMesh.new()
		rib_mesh.inner_radius = 0.112
		rib_mesh.outer_radius = 0.128
		rib.mesh = rib_mesh
		rib.position.y = -0.07 + rib_index * 0.045
		rib.material_override = shell_mat
		projectile.add_child(rib)
	var lever := MeshInstance3D.new()
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.2, 0.026, 0.045)
	lever.mesh = lever_mesh
	lever.position = Vector3(0.12, 0.13, 0)
	lever.material_override = shell_mat
	projectile.add_child(lever)
	add_child(projectile)
	projectile.linear_velocity = direction.normalized() * 17.0 + Vector3.UP * 5.2
	projectile.angular_velocity = Vector3(5.0, 3.0, 2.0)
	var fuse := 1.5 if kind == "flash" else 2.0
	get_tree().create_timer(fuse).timeout.connect(_explode_grenade.bind(kind, projectile))
	_chat_message("UTILITY", "%s thrown." % kind.to_upper())

func _explode_grenade(kind: String, projectile: RigidBody3D) -> void:
	if not is_instance_valid(projectile): return
	var point := projectile.global_position
	projectile.queue_free()
	_chat_message("UTILITY", "%s detonated." % kind.to_upper())
	match kind:
		"he":
			for bot in bot_nodes.duplicate():
				if not is_instance_valid(bot) or int(bot.get("hp")) <= 0: continue
				var distance := point.distance_to(bot.global_position + Vector3.UP)
				if distance < 9.0:
					var amount := int(100.0 * (1.0 - distance / 10.0))
					if amount > 0: bot.call("take_damage", amount, false, true, player)
		"flash":
			if player.global_position.distance_to(point) < 18.0:
				flash_overlay.color = Color(1, 1, 1, 0.92)
				var tween := create_tween()
				tween.tween_property(flash_overlay, "color:a", 0.0, 2.4).set_trans(Tween.TRANS_SINE)
		"smoke":
			_create_smoke_cloud(point)
		"molotov":
			_create_molotov(point)

func _create_smoke_cloud(point: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.name = "Expanding Smoke Cloud"
	cloud.position = point
	add_child(cloud)
	for i in range(7):
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		puff_mesh.radius = 2.1 if i == 0 else 1.65
		puff_mesh.height = puff_mesh.radius * 2.0
		puff.mesh = puff_mesh
		puff.position = Vector3(cos(float(i) * TAU / 6.0) * 1.2, 0.3 + float(i % 3) * 0.55, sin(float(i) * TAU / 6.0) * 1.2) if i > 0 else Vector3.ZERO
		var smoke_mat := StandardMaterial3D.new()
		smoke_mat.albedo_color = Color(0.62, 0.66, 0.65, 0.33)
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = smoke_mat
		cloud.add_child(puff)
	grenade_clouds.append(cloud)
	get_tree().create_timer(18.0).timeout.connect(func():
		if is_instance_valid(cloud): cloud.queue_free()
		grenade_clouds.erase(cloud)
	)

func _create_molotov(point: Vector3) -> void:
	var fire := Node3D.new()
	fire.name = "Molotov Fire"
	fire.position = point
	add_child(fire)
	for i in range(11):
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = rng.randf_range(0.25, 0.55)
		flame_mesh.height = flame_mesh.radius * 2.6
		flame.mesh = flame_mesh
		flame.position = Vector3(rng.randf_range(-2.3, 2.3), rng.randf_range(0.15, 0.5), rng.randf_range(-2.3, 2.3))
		var flame_mat := StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, rng.randf_range(0.12, 0.48), 0.025, 0.88)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.2, 0.025)
		flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flame.material_override = flame_mat
		fire.add_child(flame)
	_apply_molotov_damage(fire)

func _apply_molotov_damage(fire: Node3D) -> void:
	for tick in range(7):
		if not is_instance_valid(fire): return
		for bot in bot_nodes.duplicate():
			if is_instance_valid(bot) and bot.global_position.distance_to(fire.global_position) < 4.3:
				bot.call("take_damage", 8, false, true, player)
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(fire): fire.queue_free()

func _start_next_5v5_round() -> void:
	for bot in bot_nodes:
		if is_instance_valid(bot): bot.queue_free()
	bot_nodes.clear()
	damage_by_bot.clear()
	damage_contributors.clear()
	spotted_enemies.clear()
	bot_stats.clear()
	scoreboard_signature = ""
	bot_styles.shuffle()
	health = 100
	damage_cooldown = 0.0
	bomb_carried = true
	player.set("has_c4", not online_match or online_team == "t")
	bomb_planted = false
	bomb_time_left = 0.0
	planted_this_round = false
	bought_this_round = 0
	grenade_purchases_this_round = 0
	if is_instance_valid(bomb_node):
		bomb_node.queue_free()
		bomb_node = null
	player.global_position = _random_spawn_position(true, online_team if online_match else "t")
	(player.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", false)
	player.velocity = Vector3.ZERO
	player.set("reloading", false)
	if str(player.get("primary_weapon")).is_empty():
		player.set("pistol_ammo", 20)
		player.set("pistol_reserve", 120)
		player.call("equip_pistol", "glock")
	else:
		player.call("equip_primary")
	_spawn_bots()
	round_resolving = false
	_refresh_hud()
	_run_round_countdown()

func _process(delta: float) -> void:
	if is_instance_valid(fps_label): fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_update_online(delta)
	for entry in online_players.values():
		var actor: Node3D = entry.get("node")
		if not is_instance_valid(actor): continue
		actor.global_position = actor.global_position.lerp(entry.get("target_position", actor.global_position), minf(1.0, delta * 14.0))
		actor.rotation.y = lerp_angle(actor.rotation.y, float(entry.get("target_yaw", actor.rotation.y)), minf(1.0, delta * 14.0))
	if not match_active or get_tree().paused: return
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	_update_round_objectives(delta)
	_update_tactical_hud()
	_refresh_hud()
	if scoreboard_panel.visible: _refresh_scoreboard()

func _connect_online(url: String, online_mode_name: String, room_name: String) -> bool:
	_disconnect_online()
	online_team = "t"
	online_player_count = 1
	online_peer = WebSocketPeer.new()
	online_join_sent = false
	online_player_id = ""
	var connect_error := online_peer.connect_to_url(url)
	if connect_error != OK:
		if is_instance_valid(online_status_label):
			online_status_label.text = "COULD NOT START CONNECTION (%s)" % error_string(connect_error)
			online_status_label.add_theme_color_override("font_color", Color("ff8d72"))
		return false
	if is_instance_valid(online_status_label):
		online_status_label.text = "CONNECTING TO MATCH SERVER…"
		online_status_label.add_theme_color_override("font_color", Color("e3b562"))
	set_meta("online_mode_name", online_mode_name)
	set_meta("online_room_name", room_name if not room_name.is_empty() else "public")
	online_connect_timer = 60.0
	return true

func _disconnect_online() -> void:
	if online_peer != null:
		online_peer.close()
		online_peer = null
	online_join_sent = false
	online_player_id = ""
	online_player_count = 1
	online_connect_timer = 0.0
	for entry in online_players.values():
		var actor: Node = entry.get("node")
		if is_instance_valid(actor): actor.queue_free()
	online_players.clear()

func _update_online(delta: float) -> void:
	if online_peer == null: return
	online_peer.poll()
	if match_active and online_player_id.is_empty():
		online_connect_timer -= delta
		if online_connect_timer <= 0.0:
			_return_to_main_menu()
			if is_instance_valid(online_status_label):
				online_status_label.text = "ONLINE SERVER DID NOT RESPOND. DEPLOY THE MATCH SERVER FIRST."
				online_status_label.add_theme_color_override("font_color", Color("ff8d72"))
			return
	if online_peer.get_ready_state() == WebSocketPeer.STATE_OPEN and not online_join_sent:
		var join_packet := {
			"type": "join",
			"mode": str(get_meta("online_mode_name", "deathmatch")),
			"room": str(get_meta("online_room_name", "public")),
			"name": "Player",
		}
		online_peer.send_text(JSON.stringify(join_packet))
		online_join_sent = true
	if online_peer.get_ready_state() == WebSocketPeer.STATE_OPEN and match_active and is_instance_valid(player):
		online_send_timer -= delta
		if online_send_timer <= 0.0:
			online_send_timer = 0.05
			var camera: Camera3D = player.get_node("Camera3D")
			online_peer.send_text(JSON.stringify({
				"type": "state",
				"position": [player.global_position.x, player.global_position.y, player.global_position.z],
				"yaw": player.rotation.y,
				"pitch": camera.rotation.x,
				"weapon": str(player.get("current_weapon")),
				"alive": health > 0,
			}))
	while online_peer != null and online_peer.get_available_packet_count() > 0:
		var packet_text := online_peer.get_packet().get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(packet_text)
		if parsed is Dictionary: _handle_online_packet(parsed)
	if online_peer != null and online_peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		var was_active := match_active
		_disconnect_online()
		if was_active: _return_to_main_menu()
		if is_instance_valid(online_status_label):
			online_status_label.text = "MATCH SERVER DISCONNECTED — CHECK SERVER URL/DEPLOYMENT"
			online_status_label.add_theme_color_override("font_color", Color("ff8d72"))

func _handle_online_packet(packet: Dictionary) -> void:
	match str(packet.get("type", "")):
		"joined":
			online_player_id = str(packet.get("id", ""))
			online_connect_timer = 0.0
			online_team = str(packet.get("team", "t"))
			if is_instance_valid(online_status_label):
				online_status_label.text = "CONNECTED  •  ROOM %s  •  TEAM %s" % [str(packet.get("room", "public")).to_upper(), online_team.to_upper()]
				online_status_label.add_theme_color_override("font_color", Color("8ee2c8"))
			if match_active: _chat_message("ONLINE", "Joined %s as %s." % [str(packet.get("room", "public")).to_upper(), online_team.to_upper()])
			if match_active and mode == "5V5":
				player.global_position = _random_spawn_position(true, online_team)
				player.set("has_c4", online_team == "t")
		"roster":
			var roster: Array = packet.get("players", [])
			online_player_count = int(packet.get("player_count", roster.size()))
			var keep: Dictionary = {}
			for info in roster:
				if not info is Dictionary: continue
				var peer_id := str(info.get("id", ""))
				if peer_id == online_player_id:
					var new_team := str(info.get("team", online_team))
					if online_match and mode == "5V5" and new_team != online_team:
						online_team = new_team
						if match_active:
							player.global_position = _random_spawn_position(true, online_team)
							player.set("has_c4", online_team == "t")
							player.velocity = Vector3.ZERO
					continue
				if peer_id.is_empty(): continue
				keep[peer_id] = true
				if not online_players.has(peer_id): _create_online_player(peer_id, str(info.get("name", "Player")), str(info.get("team", "dm")))
				else:
					var updated_team := str(info.get("team", "dm"))
					online_players[peer_id]["team"] = updated_team
					var avatar_material: StandardMaterial3D = online_players[peer_id].get("material")
					if is_instance_valid(avatar_material): avatar_material.albedo_color = _online_team_color(updated_team)
			for peer_id in online_players.keys():
				if keep.has(peer_id): continue
				var old_actor: Node = online_players[peer_id].get("node")
				if is_instance_valid(old_actor): old_actor.queue_free()
				online_players.erase(peer_id)
			if online_match and mode == "5V5":
				if online_player_count >= 2:
					for bot in bot_nodes:
						if is_instance_valid(bot): bot.queue_free()
					bot_nodes.clear()
					bot_stats.clear()
					_chat_message("MATCH", "Human players joined. Bots are removed and teams are balanced.")
				elif bot_nodes.is_empty():
					_spawn_bots()
					if round_live:
						for bot in bot_nodes: bot.set_physics_process(true)
		"state":
			var peer_id := str(packet.get("id", ""))
			if online_players.has(peer_id):
				var entry: Dictionary = online_players[peer_id]
				var p: Array = packet.get("position", [])
				if p.size() == 3:
					var next_position := Vector3(float(p[0]), float(p[1]), float(p[2]))
					entry["target_position"] = next_position
					if not bool(entry.get("has_state", false)):
						var initial_actor: Node3D = entry.get("node")
						if is_instance_valid(initial_actor): initial_actor.global_position = next_position
						entry["has_state"] = true
				entry["target_yaw"] = float(packet.get("yaw", 0.0))
				entry["weapon"] = str(packet.get("weapon", "rifle"))
				var was_alive := bool(entry.get("alive", true))
				entry["alive"] = bool(packet.get("alive", true))
				if entry["alive"] and not was_alive: entry["health"] = 100
				var actor: Node3D = entry.get("node")
				if is_instance_valid(actor):
					actor.visible = entry["alive"]
					var actor_collision := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
					if is_instance_valid(actor_collision): actor_collision.set_deferred("disabled", not entry["alive"])
					var held_weapon := actor.get_node_or_null("RemoteWeapon") as MeshInstance3D
					if is_instance_valid(held_weapon): held_weapon.visible = str(entry["weapon"]) != "knife"
				if mode == "5V5": _check_5v5_round_end()
		"hit":
			var shooter_id := str(packet.get("shooter", ""))
			var target_id := str(packet.get("target", ""))
			var weapon_name := str(packet.get("weapon", "rifle"))
			var is_headshot := bool(packet.get("headshot", false))
			var dealt := int(packet.get("damage", 50))
			var attacker: Node3D = online_players.get(shooter_id, {}).get("node")
			if target_id == online_player_id:
				player_hit(dealt, attacker, is_headshot, _weapon_display_name(weapon_name))
			elif online_players.has(target_id):
				var victim: Dictionary = online_players[target_id]
				victim["health"] = int(packet.get("target_health", maxi(0, int(victim.get("health", 100)) - dealt)))
				victim["alive"] = bool(packet.get("killed", int(victim["health"]) <= 0)) == false
				var victim_node: Node3D = victim.get("node")
				if is_instance_valid(victim_node):
					victim_node.visible = victim["alive"]
					var victim_collider := victim_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
					if is_instance_valid(victim_collider): victim_collider.set_deferred("disabled", not victim["alive"])
				if shooter_id == online_player_id:
					damage_dealt += dealt
					if bool(packet.get("killed", false)):
						kills += 1
						_add_killfeed_entry("YOU", str(victim.get("name", "PLAYER")), weapon_name, is_headshot)
			if mode == "5V5": _check_5v5_round_end()
		"error":
			if is_instance_valid(online_status_label):
				online_status_label.text = str(packet.get("message", "MATCH SERVER ERROR"))
				online_status_label.add_theme_color_override("font_color", Color("ff8d72"))
			if match_active and online_player_id.is_empty():
				var server_error := str(packet.get("message", "MATCH SERVER ERROR"))
				_return_to_main_menu()
				if is_instance_valid(online_status_label): online_status_label.text = server_error
			elif match_active: _chat_message("ONLINE", str(packet.get("message", "MATCH SERVER ERROR")))

func _create_online_player(peer_id: String, display_name: String, team: String) -> void:
	var actor := CharacterBody3D.new()
	actor.name = "Online_" + peer_id
	actor.add_to_group("online_players")
	actor.collision_layer = 1
	actor.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	collider.disabled = true
	actor.add_child(collider)
	var body := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.48
	capsule_mesh.height = 1.8
	body.mesh = capsule_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _online_team_color(team)
	body.material_override = material
	actor.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.position.y = 1.78
	head.material_override = material
	actor.add_child(head)
	var rifle := MeshInstance3D.new()
	rifle.name = "RemoteWeapon"
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.12, 0.13, 0.72)
	rifle.mesh = rifle_mesh
	rifle.position = Vector3(0.35, 1.18, -0.3)
	var rifle_material := StandardMaterial3D.new()
	rifle_material.albedo_color = Color("252a29")
	rifle_material.metallic = 0.55
	rifle_material.roughness = 0.4
	rifle.material_override = rifle_material
	actor.add_child(rifle)
	var name_tag := Label3D.new()
	name_tag.name = "PlayerName"
	name_tag.text = display_name
	name_tag.position.y = 2.25
	name_tag.font_size = 28
	name_tag.pixel_size = 0.008
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.modulate = Color("d9e3df")
	actor.add_child(name_tag)
	actor.visible = false
	add_child(actor)
	online_players[peer_id] = {"node": actor, "name": display_name, "team": team, "material": material, "health": 100, "alive": true, "target_position": Vector3.ZERO, "target_yaw": 0.0, "has_state": false}

func _online_team_color(team: String) -> Color:
	if team == "t": return Color("4c8290")
	if team == "ct": return Color("bd7043")
	return Color("d2ad54")

func _update_tactical_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(radar_canvas): return
	var allies := get_tree().get_nodes_in_group("allies")
	var enemies := get_tree().get_nodes_in_group("bots")
	var friendly_count := 0
	var enemy_count := 0
	if health > 0: friendly_count += 1
	for ally in allies:
		if not is_instance_valid(ally) or int(ally.get("hp")) <= 0: continue
		friendly_count += 1
	for enemy in enemies:
		if not is_instance_valid(enemy) or int(enemy.get("hp")) <= 0: continue
		enemy_count += 1
	for entry in online_players.values():
		if not bool(entry.get("alive", true)): continue
		if str(entry.get("team", "")) == online_team: friendly_count += 1
		elif mode == "5V5": enemy_count += 1
	var friendly_icons := ""
	var enemy_icons := ""
	for i in range(5):
		friendly_icons += ("● " if i < friendly_count else "☠ ")
		enemy_icons += ("● " if i < enemy_count else "☠ ")
	team_alive_label.text = friendly_icons.strip_edges()
	enemy_alive_label.text = enemy_icons.strip_edges()
	team_alive_label.visible = mode == "5V5"
	enemy_alive_label.visible = mode == "5V5"
	if mode != "5V5":
		radar_panel.hide()
		return
	radar_panel.show()
	var now := float(Time.get_ticks_msec()) / 1000.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or int(enemy.get("hp")) <= 0: continue
		if _player_can_spot(enemy):
			spotted_enemies[enemy.get_instance_id()] = {"position": enemy.global_position, "expires": now + 5.0}
	for key in spotted_enemies.keys():
		if float(spotted_enemies[key].get("expires", 0.0)) <= now:
			spotted_enemies.erase(key)
	for mark in radar_marks: mark.hide()
	_set_radar_mark(0, player.global_position, Color("73e6c8"), 11.0)
	if is_instance_valid(radar_player_arrow):
		var radar_center := radar_canvas.size * 0.5
		if radar_canvas.size.x <= 0.0 or radar_canvas.size.y <= 0.0:
			radar_center = radar_canvas.custom_minimum_size * 0.5
		radar_map_layer.size = radar_canvas.size if radar_canvas.size.x > 0.0 else radar_canvas.custom_minimum_size
		radar_map_layer.pivot_offset = radar_center
		radar_map_layer.rotation = player.rotation.y
		radar_map_layer.scale = Vector2.ONE * RADAR_ZOOM
		radar_background.size = radar_map_layer.size
		radar_background.position = radar_center - _world_to_radar_map(player.global_position)
		radar_player_arrow.position = radar_center
		radar_player_arrow.rotation = 0.0
		radar_player_arrow.visible = true
		radar_marks[0].hide()
	for i in range(mini(4, allies.size())):
		var ally: Node3D = allies[i]
		if int(ally.get("hp")) > 0: _set_radar_mark(i + 1, ally.global_position, Color("73e6c8"), 8.0)
	var slot := 5
	var online_ally_slot := 1 + mini(3, allies.size())
	for entry in online_players.values():
		var actor: Node3D = entry.get("node")
		if not is_instance_valid(actor) or not bool(entry.get("alive", true)): continue
		if str(entry.get("team", "")) == online_team:
			if online_ally_slot <= 4: _set_radar_mark(online_ally_slot, actor.global_position, Color("73e6c8"), 8.0)
			online_ally_slot += 1
		elif _player_can_spot(actor):
			spotted_enemies[actor.get_instance_id()] = {"position": actor.global_position, "expires": now + 5.0}
	for key in spotted_enemies:
		if slot >= radar_marks.size(): break
		var data: Dictionary = spotted_enemies[key]
		_set_radar_mark(slot, data["position"], Color("ff6f59"), 8.0)
		slot += 1

func _player_can_spot(target: Node3D) -> bool:
	var start := player.global_position + Vector3.UP * 1.35
	var finish := target.global_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target

func _set_radar_mark(index: int, world_position: Vector3, color: Color, size: float) -> void:
	if index < 0 or index >= radar_marks.size(): return
	var mark := radar_marks[index]
	mark.position = _world_to_radar(world_position) - Vector2(size * 0.5, size * 0.5)
	mark.size = Vector2(size, size)
	mark.color = color
	mark.show()

func _world_to_radar(world_position: Vector3) -> Vector2:
	var radar_center := radar_canvas.size * 0.5
	if radar_canvas.size.x <= 0.0 or radar_canvas.size.y <= 0.0:
		radar_center = radar_canvas.custom_minimum_size * 0.5
	var player_map_position := _world_to_radar_map(player.global_position)
	var target_map_position := _world_to_radar_map(world_position)
	return radar_center + target_map_position - player_map_position

func _world_to_radar_map(world_position: Vector3) -> Vector2:
	var map_width := DUST2_MAP_MAX_X - DUST2_MAP_MIN_X
	var map_depth := DUST2_MAP_MAX_Z - DUST2_MAP_MIN_Z
	var map_scale := minf((RADAR_IMAGE_SIZE - RADAR_IMAGE_PADDING * 2.0) / map_width, (RADAR_IMAGE_SIZE - RADAR_IMAGE_PADDING * 2.0) / map_depth)
	var image_x_padding := (RADAR_IMAGE_SIZE - map_width * map_scale) * 0.5
	var image_z_padding := (RADAR_IMAGE_SIZE - map_depth * map_scale) * 0.5
	var image_x := image_x_padding + (world_position.x - DUST2_MAP_MIN_X) * map_scale
	var image_y := image_z_padding + (world_position.z - DUST2_MAP_MIN_Z) * map_scale
	var canvas_size := radar_canvas.size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0: canvas_size = radar_canvas.custom_minimum_size
	return Vector2(image_x / RADAR_IMAGE_SIZE * canvas_size.x, image_y / RADAR_IMAGE_SIZE * canvas_size.y)

func _unhandled_input(event: InputEvent) -> void:
	if not match_active: return
	if event is InputEventKey and event.keycode == KEY_TAB:
		if event.pressed and not event.echo: _refresh_scoreboard()
		scoreboard_panel.visible = event.pressed
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if chat_input.visible:
			if event.keycode == KEY_ESCAPE:
				chat_input.hide()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if get_tree().paused:
				_resume_match()
			else:
				_open_pause_menu()
		elif event.keycode == KEY_B:
			buy_panel.visible = not buy_panel.visible
			player.set("buy_menu_open", buy_panel.visible)
			if buy_panel.visible and not buy_phase:
				buy_panel.hide()
				player.set("buy_menu_open", false)
				_chat_message("BUY MENU", "Buy time has expired.")
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if buy_panel.visible else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_Y:
			chat_input.show()
			chat_input.grab_focus()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_try_bomb_interaction()
		elif event.keycode == KEY_1 and buy_panel.visible:
			_buy_item("1 AK-47")
		elif event.keycode == KEY_2 and buy_panel.visible:
			_buy_item("2 Glock-18")
		elif event.keycode == KEY_3 and buy_panel.visible:
			_buy_item("3 USP-S")
		elif event.keycode == KEY_4 and buy_panel.visible:
			_buy_item("4 awp")
		elif event.keycode == KEY_5 and buy_panel.visible:
			_buy_item("5 armor")
		elif event.keycode == KEY_6 and buy_panel.visible: _buy_item("6 he grenade")
		elif event.keycode == KEY_7 and buy_panel.visible: _buy_item("7 smoke")
		elif event.keycode == KEY_8 and buy_panel.visible: _buy_item("8 flash")
		elif event.keycode == KEY_9 and buy_panel.visible: _buy_item("9 molotov")

func _buy_item(item: String) -> void:
	if not buy_phase:
		_chat_message("ARMORY", "Purchases are only available during the 15-second buy period.")
		return
	var lower := item.to_lower()
	var price := 0
	if lower.contains("awp"): price = 4750
	elif lower.contains("ak") or lower.contains("rifle"): price = 2700
	elif lower.contains("glock"): price = 200
	elif lower.contains("usp") or lower.contains("pistol"): price = 200
	elif lower.contains("armor") or lower.contains("helmet"): price = 1000
	elif lower.contains("he grenade") or lower.ends_with(" he"): price = 300
	elif lower.contains("smoke"): price = 300
	elif lower.contains("flash"): price = 200
	elif lower.contains("molotov"): price = 400
	if money < price:
		_chat_message("ARMORY", "Not enough money. Need $%d, you have $%d." % [price, money])
		return
	if lower.contains("he grenade") or lower.ends_with(" he") or lower.contains("smoke") or lower.contains("flash") or lower.contains("molotov"):
		var kind := "he" if lower.contains("he grenade") else "smoke" if lower.contains("smoke") else "flash" if lower.contains("flash") else "molotov"
		var stock: Dictionary = player.get("grenades")
		var total := 0
		for count in stock.values(): total += int(count)
		var max_kind := 2 if kind == "flash" else 1
		if grenade_purchases_this_round >= 4 or total >= 4 or int(stock.get(kind, 0)) >= max_kind:
			_chat_message("ARMORY", "Grenade limit reached (4 total; 2 flashbangs max).")
			return
		stock[kind] = int(stock.get(kind, 0)) + 1
		grenade_purchases_this_round += 1
		player.set("grenades", stock)
		player.call("equip_grenade", kind)
	elif lower.contains("glock") or lower.contains("usp") or lower.contains("pistol"):
		player.set("pistol_ammo", 12)
		player.set("pistol_reserve", 48)
		var pistol_model := "glock" if lower.contains("glock") else "usp"
		player.set("pistol_model", pistol_model)
		player.call("equip_pistol", pistol_model)
	elif lower.contains("awp"):
		player.set("awp_ammo", 5)
		player.set("awp_reserve", 30)
		player.set("primary_weapon", "awp")
		player.call("equip_awp")
	elif lower.contains("armor") or lower.contains("helmet") or lower.contains("kevlar"):
		armor = 100
		armor_helmet = true
	else:
		player.set("primary_weapon", "rifle")
		player.call("equip_primary")
		player.set("ammo", 30)
		player.set("reserve", 90)
		ammo_label.text = "AK-STYLE RIFLE     30 / 90"
	money -= price
	bought_this_round += 1
	_chat_message("PURCHASE", "%s  −$%d  |  Balance $%d" % [item, price, money])
	_refresh_hud()
	buy_panel.hide()
	player.set("buy_menu_open", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_chat_submitted(text: String) -> void:
	var clean := text.strip_edges()
	if not clean.is_empty(): _chat_message("YOU", clean)
	chat_input.clear()
	chat_input.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _chat_message(speaker: String, text: String) -> void:
	if not is_instance_valid(chat_log): return
	chat_log.push_color(Color("e3b562"))
	chat_log.add_text(speaker)
	chat_log.pop()
	chat_log.add_text("  %s\n" % text)
	chat_log.scroll_to_line(maxi(0, chat_log.get_line_count() - 1))

func _add_money(amount: int, reason: String) -> void:
	var before := money
	money = mini(16000, money + amount)
	var paid := money - before
	_chat_message("ECONOMY", "%s: +$%d  |  Balance $%d" % [reason, paid, money])
	_refresh_hud()

func _open_pause_menu() -> void:
	buy_panel.hide()
	pause_panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_match() -> void:
	get_tree().paused = false
	pause_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _return_to_main_menu() -> void:
	get_tree().paused = false
	pause_panel.hide()
	match_active = false
	_disconnect_online()
	round_live = false
	round_resolving = false
	countdown_label.hide()
	scoreboard_panel.hide()
	player.set_physics_process(false)
	(player.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", false)
	for bot in bot_nodes:
		if is_instance_valid(bot): bot.queue_free()
	bot_nodes.clear()
	hud.hide()
	_show_menu()

func _on_player_fired(target: Node3D, headshot: bool) -> void:
	if target == null or not is_instance_valid(target): return
	if target.is_in_group("online_players") and online_peer != null and online_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var target_id := str(target.name).trim_prefix("Online_")
		var remote_team := str(online_players.get(target_id, {}).get("team", "dm"))
		if mode == "5V5" and remote_team == online_team: return
		online_peer.send_text(JSON.stringify({"type": "hit", "target": target_id, "weapon": str(player.get("current_weapon")), "headshot": headshot}))
		return
	if target.is_in_group("bots") and target.has_method("take_damage"):
		var weapon := str(player.get("current_weapon"))
		last_kill_reward = 1500 if weapon == "knife" else 100 if weapon == "awp" else 300
		var damage := 50
		if weapon == "pistol": damage = 35
		if weapon == "awp" or headshot or weapon == "knife": damage = 100
		var dealt := mini(damage, maxi(0, int(target.get("hp"))))
		damage_dealt += dealt
		var target_id := target.get_instance_id()
		damage_by_bot[target_id] = int(damage_by_bot.get(target_id, 0)) + dealt
		_record_contribution(target_id, player.get_instance_id(), dealt)
		target.call("take_damage", damage, headshot, true)

func _on_reloaded() -> void:
	kill_label.text = "▰  MAGAZINE SEATED  ▰"
	kill_label.add_theme_color_override("font_color", Color("89d5de"))
	get_tree().create_timer(1.2).timeout.connect(func(): kill_label.text = "")

func _on_scope_changed(enabled: bool) -> void:
	crosshair.visible = not enabled
	scope_reticle.visible = enabled

func bot_killed(bot: Node3D, headshot: bool) -> void:
	kills += 1
	if headshot: headshot_kills += 1
	damage_by_bot.erase(bot.get_instance_id())
	var victim_id := bot.get_instance_id()
	if bot_stats.has(victim_id):
		bot_stats[victim_id]["deaths"] += 1
		bot_stats[victim_id]["score"] -= 50
	damage_by_bot.erase(victim_id)
	_award_assists(victim_id, player.get_instance_id())
	if mode == "5V5": _add_money(last_kill_reward, "Kill reward")
	_add_killfeed_entry("YOU", _bot_display_name(bot), _weapon_display_name(str(player.get("current_weapon"))), headshot)
	bot_nodes.erase(bot)
	var message := "✦  HEADSHOT   +300" if headshot else "ELIMINATION   +200"
	kill_label.text = message
	kill_label.add_theme_color_override("font_color", Color("ffcf67"))
	get_tree().create_timer(2.0).timeout.connect(func(): kill_label.text = "")
	if mode == "5V5":
		_check_5v5_round_end()
		return
	get_tree().create_timer(2.5).timeout.connect(func():
		if match_active: _spawn_replacement()
	)

func bot_died(bot: Node3D, was_teammate: bool, killer: Node3D = null, headshot: bool = false) -> void:
	bot_nodes.erase(bot)
	var victim_id := bot.get_instance_id()
	if bot_stats.has(victim_id):
		bot_stats[victim_id]["deaths"] += 1
		bot_stats[victim_id]["score"] -= 50
	damage_by_bot.erase(victim_id)
	var killer_id := -1
	if is_instance_valid(killer) and bot_stats.has(killer.get_instance_id()):
		killer_id = killer.get_instance_id()
		bot_stats[killer_id]["kills"] += 1
		bot_stats[killer_id]["score"] += 100
		if headshot: bot_stats[killer_id]["headshot_kills"] += 1
		_add_killfeed_entry(_bot_display_name(killer), _bot_display_name(bot), "AK-47", headshot)
	_award_assists(victim_id, killer_id)
	if mode == "5V5":
		_check_5v5_round_end()
		return
	get_tree().create_timer(2.5).timeout.connect(func():
		if match_active: _spawn_replacement(was_teammate)
	)

func _spawn_replacement(is_teammate: bool = false) -> void:
	if not match_active or mode == "5V5": return
	var bot: CharacterBody3D = CharacterBody3D.new()
	bot.set_script(BOT_SCRIPT)
	if is_teammate:
		bot.position = _random_spawn_position(false, online_team if online_match else "t")
		bot.add_to_group("allies")
	else:
		var enemy_side := "ct" if not online_match or online_team == "t" else "t"
		bot.position = _random_spawn_position(false, enemy_side if mode == "5V5" else "any")
		bot.add_to_group("bots")
		bot.add_to_group("bot_heads")
	bot.set_physics_process(true)
	add_child(bot)
	bot.call("setup", player, self, is_teammate, bot_styles[rng.randi_range(0, bot_styles.size() - 1)])
	_register_bot_stats(bot, ("ALLY" if is_teammate else "RIVAL") + "  /  " + str(bot.get("style")))
	bot_nodes.append(bot)

func _random_spawn_position(for_player: bool, team_side: String = "any") -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.7
	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	if is_instance_valid(player): excluded.append(player.get_rid())
	for entry in online_players.values():
		var online_actor: Node3D = entry.get("node")
		if is_instance_valid(online_actor): excluded.append(online_actor.get_rid())
	for bot in bot_nodes:
		if is_instance_valid(bot): excluded.append(bot.get_rid())
	for attempt in range(300):
		# The map has balconies and roofs far above its base plane. Only accept
		# actual collision surfaces on the measured T/CT spawn deck; the old
		# 50-unit ray could select a roof and strand the player above the map.
		var spawn_floor_y := DUST2_SPAWN_DECK_Y
		var x := 0.0
		var z := 0.0
		if team_side == "t":
			# T spawn is the southwest spawn yard (south is positive Z).
			x = rng.randf_range(-108.0, -72.0)
			z = rng.randf_range(118.0, 132.0)
		elif team_side == "ct":
			# CT spawn is the northeast yard, opposite T across the map.
			x = rng.randf_range(80.0, 102.0)
			z = rng.randf_range(-124.0, -108.0)
		else:
			# Practice and Deathmatch use the same two verified spawn yards.
			# Randomly placing at arbitrary X/Z coordinates used to select roofs,
			# balconies, or unsupported points on this structures-only model.
			if rng.randf() < 0.5:
				x = rng.randf_range(-108.0, -72.0)
				z = rng.randf_range(118.0, 132.0)
			else:
				x = rng.randf_range(80.0, 102.0)
				z = rng.randf_range(-124.0, -108.0)
		var search_top := spawn_floor_y + 0.5
		var floor_query := PhysicsRayQueryParameters3D.create(
			Vector3(x, search_top, z),
			Vector3(x, spawn_floor_y - 0.5, z),
			1,
			excluded
		)
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty(): continue
		var floor_point: Vector3 = floor_hit["position"]
		if absf(floor_point.y - spawn_floor_y) > 0.45: continue
		# Check full player height above the selected spawn-deck surface.
		var clearance_query := PhysicsRayQueryParameters3D.create(
			Vector3(x, floor_point.y + 2.9, z),
			Vector3(x, floor_point.y + 0.2, z),
			1,
			excluded
		)
		if not space.intersect_ray(clearance_query).is_empty(): continue
		# Player and bot origins are at their feet; their capsule centers sit 1.35 m up.
		var root_y := floor_point.y + 0.03
		var center := Vector3(x, root_y + 1.35, z)
		var candidate_spawn := Vector3(x, root_y, z)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, center)
		query.collision_mask = 1
		query.exclude = excluded
		if space.intersect_shape(query, 1).is_empty():
			return candidate_spawn
	# Never fall back to a synthetic plane. Resolve a real upper map surface at
	# checked open points in each team's actual spawn yard.
	var fallback_x := -90.3 if team_side == "t" else 99.0 if team_side == "ct" else -90.3
	var fallback_z := 129.1 if team_side == "t" else -120.0 if team_side == "ct" else 129.1
	var fallback_query := PhysicsRayQueryParameters3D.create(
		Vector3(fallback_x, DUST2_SPAWN_DECK_Y + 0.5, fallback_z),
		Vector3(fallback_x, DUST2_SPAWN_DECK_Y - 0.5, fallback_z),
		1,
		excluded
	)
	var fallback_hit := space.intersect_ray(fallback_query)
	if not fallback_hit.is_empty():
		var fallback_point: Vector3 = fallback_hit["position"]
		if absf(fallback_point.y - DUST2_SPAWN_DECK_Y) <= 0.45:
			return Vector3(fallback_x, fallback_point.y + 0.05, fallback_z)
	# The checked deck coordinates are the final guard if collision queries have
	# not synchronized yet; this prevents ever choosing a higher roof by accident.
	if team_side == "ct": return Vector3(99.0, DUST2_SPAWN_DECK_Y + 0.05, -120.0)
	return Vector3(-90.3, DUST2_SPAWN_DECK_Y + 0.05, 129.1)

func player_hit(amount: int, attacker: Node3D = null, headshot: bool = false, weapon: String = "AK-47") -> void:
	if not match_active or damage_cooldown > 0.0: return
	damage_cooldown = 0.6
	if is_instance_valid(player): player.call("play_damage_sound")
	if armor > 0:
		var absorbed := mini(armor, int(ceil(float(amount) * 0.5)))
		armor -= absorbed
		amount -= absorbed
	health -= amount
	if is_instance_valid(attacker):
		var attacker_id := attacker.get_instance_id()
		if bot_stats.has(attacker_id): bot_stats[attacker_id]["damage"] += amount
		_record_contribution(player.get_instance_id(), attacker_id, amount)
	if health <= 0:
		deaths += 1
		var killer_id := attacker.get_instance_id() if is_instance_valid(attacker) else -1
		if bot_stats.has(killer_id):
			bot_stats[killer_id]["kills"] += 1
			bot_stats[killer_id]["score"] += 100
		_award_assists(player.get_instance_id(), killer_id)
		if is_instance_valid(attacker):
			_add_killfeed_entry(_bot_display_name(attacker), "YOU", weapon, headshot)
		else:
			_add_killfeed_entry("UNKNOWN", "YOU", weapon, headshot)
		player.velocity = Vector3.ZERO
		if mode == "5V5":
			(player.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", true)
			player.set("movement_locked", true)
			player.set_physics_process(false)
			kill_label.text = "ELIMINATED  •  ROUND CONTINUES"
			_check_5v5_round_end()
		else:
			health = 100
			player.global_position = _random_spawn_position(true, "any")
			kill_label.text = "ELIMINATED  •  RESPAWNING"
			get_tree().create_timer(1.5).timeout.connect(func(): kill_label.text = "")
	_refresh_hud()

func _bot_display_name(bot: Node3D) -> String:
	if bot == player: return "YOU"
	if not is_instance_valid(bot): return "UNKNOWN"
	var stats: Dictionary = bot_stats.get(bot.get_instance_id(), {})
	return str(stats.get("name", "BOT"))

func _weapon_display_name(weapon: String) -> String:
	match weapon:
		"rifle": return "AK-47"
		"pistol": return "USP-S"
		"awp": return "AWP"
		"knife": return "KNIFE"
	return weapon.to_upper()

func _add_killfeed_entry(killer_name: String, victim_name: String, weapon: String, headshot: bool) -> void:
	if not is_instance_valid(killfeed): return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var text_color := Color("f0f1ed")
	var killer_label := _label(killer_name, 16, text_color)
	killer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(killer_label)
	var weapon_label := _label("  %s  %s  " % ["⌖" if weapon == "knife" else "➜", weapon.to_upper()], 15, Color("e3b562"))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(weapon_label)
	var victim_label := _label(victim_name, 16, text_color)
	row.add_child(victim_label)
	if headshot:
		var headshot_label := _label("  ☠ HS", 14, Color("ffcf67"))
		row.add_child(headshot_label)
	killfeed.add_child(row)
	while killfeed.get_child_count() > 6:
		var oldest := killfeed.get_child(0)
		killfeed.remove_child(oldest)
		oldest.queue_free()
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(row): row.queue_free()
	)

func _refresh_hud() -> void:
	if not is_instance_valid(player): return
	var status := "%d HP   •   $%d" % [health, money]
	if armor > 0: status += "   •   ARMOR %d%s" % [armor, " + HELMET" if armor_helmet else ""]
	if mode == "5V5":
		status += "   •   C4 PLANTED  %02d" % ceili(bomb_time_left) if bomb_planted else "   •   C4 CARRIED" if bomb_carried else "   •   C4 LOST"
	status += "   •   " + map_name
	status_label.text = status
	if mode == "5V5":
		score_label.text = "T  %02d   :   %02d  CT   /   ROUND %02d" % [round_t_wins, round_ct_wins, round_t_wins + round_ct_wins + 1]
	else:
		score_label.text = "%02d   :   %02d   /   %s" % [kills, deaths, mode]
	if player.get("reloading"):
		ammo_label.text = "RELOADING   ▰▰▱▱▱"
	elif player.get("knife_equipped"):
		ammo_label.text = "TACTICAL KNIFE     MELEE"
	elif player.get("current_weapon") == "c4":
		ammo_label.text = "C4     E TO PLANT AT A SITE"
	elif player.get("current_weapon") == "pistol":
		var pistol_name := "GLOCK-18" if str(player.get("pistol_model")) == "glock" else "USP-S"
		ammo_label.text = "%s     %02d / %02d" % [pistol_name, player.get("pistol_ammo"), player.get("pistol_reserve")]
	elif player.get("current_weapon") == "awp":
		ammo_label.text = "AWP     %02d / %02d" % [player.get("awp_ammo"), player.get("awp_reserve")]
	elif player.get("current_weapon") == "grenade":
		var grenade_stock: Dictionary = player.get("grenades")
		var grenade_kind := str(player.get("grenade_kind"))
		ammo_label.text = "%s GRENADE     x%d" % [grenade_kind.to_upper(), int(grenade_stock.get(grenade_kind, 0))]
	else:
		ammo_label.text = "AK-47     %02d / %02d" % [player.get("ammo"), player.get("reserve")]

func _refresh_scoreboard() -> void:
	if not is_instance_valid(scoreboard_rows): return
	var rows: Array[Dictionary] = []
	var player_hs := int(round(float(headshot_kills) * 100.0 / float(maxi(1, kills))))
	rows.append({"name": "YOU", "kills": kills, "deaths": deaths, "assists": assists, "score": kills * 100 + assists * 50, "damage": damage_dealt, "hs": player_hs, "player": true})
	for bot_id in bot_stats:
		rows.append(bot_stats[bot_id])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.get("player", false): return true
		if b.get("player", false): return false
		return int(a["score"]) > int(b["score"])
	)
	var signature := ""
	for row in rows:
		var hs_percent := _scoreboard_headshot_percent(row)
		var line := "%s|%d|%d|%d|%d|%d|%d" % [row["name"], row["kills"], row["deaths"], row["assists"], row["score"], row["damage"], hs_percent]
		signature += line + "\n"
	if signature == scoreboard_signature: return
	scoreboard_signature = signature
	for child in scoreboard_rows.get_children():
		scoreboard_rows.remove_child(child)
		child.queue_free()
	for row in rows:
		var hs_percent := _scoreboard_headshot_percent(row)
		var row_text := "%-30s %3d    %3d    %3d    %6d    %7d    %3d%%" % [row["name"], row["kills"], row["deaths"], row["assists"], row["score"], row["damage"], hs_percent]
		var row_label := _label(row_text, 15, Color("e9eeee") if row.get("player", false) else Color("cbd3d3"))
		scoreboard_rows.add_child(row_label)

func _scoreboard_headshot_percent(row: Dictionary) -> int:
	if row.has("headshot_kills"):
		return int(round(float(row["headshot_kills"]) * 100.0 / float(maxi(1, int(row["kills"])))))
	return int(row.get("hs", 0))

func _register_bot_stats(bot: Node3D, display_name: String) -> void:
	bot_stats[bot.get_instance_id()] = {"name": display_name, "kills": 0, "deaths": 0, "assists": 0, "score": 0, "damage": 0, "headshot_kills": 0}
	scoreboard_signature = ""

func _record_contribution(target_id: int, attacker_id: int, amount: int) -> void:
	if amount <= 0: return
	if not damage_contributors.has(target_id): damage_contributors[target_id] = {}
	var contributions: Dictionary = damage_contributors[target_id]
	contributions[attacker_id] = int(contributions.get(attacker_id, 0)) + amount

func _award_assists(victim_id: int, killer_id: int) -> void:
	if not damage_contributors.has(victim_id): return
	var contributions: Dictionary = damage_contributors[victim_id]
	for attacker_id in contributions:
		if attacker_id == killer_id: continue
		if attacker_id == player.get_instance_id():
			assists += 1
		elif bot_stats.has(attacker_id):
			bot_stats[attacker_id]["assists"] += 1
			bot_stats[attacker_id]["score"] += 50
	damage_contributors.erase(victim_id)

func record_bot_damage(attacker: Node3D, target: Node3D, amount: int, headshot: bool) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	var attacker_id := attacker.get_instance_id()
	var target_id := target.get_instance_id()
	if bot_stats.has(attacker_id):
		bot_stats[attacker_id]["damage"] += amount
	_record_contribution(target_id, attacker_id, amount)
