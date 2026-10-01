extends CharacterBody3D

signal fired(hit: Node3D, headshot: bool)
signal reloaded
signal scope_changed(enabled: bool)
signal grenade_thrown(kind: String, origin: Vector3, direction: Vector3)

const WALK_SPEED := 11.5
const RUN_SPEED := 17.0
const CROUCH_SPEED := 7.0
const GROUND_ACCEL := 10.0
const AIR_ACCEL := 2.4
const GROUND_FRICTION := 6.0
const STOP_SPEED := 6.5
const AIR_SPEED_CAP := 21.0
const AIR_STRAFE_SPEED := 5.5
const GRAVITY := 22.0
const JUMP_VELOCITY := 8.82 # About 1.5x the previous jump height with the same gravity.
const MAG_SIZE := 30
const FIRE_INTERVAL := 0.19

@onready var camera: Camera3D = $Camera3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var ammo := MAG_SIZE
var reserve := 90
var pistol_ammo := 12
var pistol_reserve := 48
var pistol_model := "usp"
var has_c4 := false
var buy_menu_open := false
var awp_ammo := 5
var awp_reserve := 30
var current_weapon := "rifle"
var grenade_kind := "he"
var grenades := {"he": 0, "smoke": 0, "flash": 0, "molotov": 0}
var primary_weapon := "rifle"
var movement_locked := true
var reloading := false
var crouched := false
var knife_equipped := false
var fire_cooldown := 0.0
var jump_buffer_left := 0.0
var reload_time := 0.0
var bob_time := 0.0
var sway_amount := 0.0
var weapon_root: Node3D
var weapon_mesh: MeshInstance3D
var knife_mesh: MeshInstance3D
var knife_root: Node3D
var grenade_root: Node3D
var c4_root: Node3D
var pistol_root: Node3D
var awp_root: Node3D
var is_scoping := false
var movement_audio: AudioStreamPlayer
var jump_audio: AudioStreamPlayer
var footstep_audio: AudioStreamPlayer
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var footstep_timer := 0.0
var rng := RandomNumberGenerator.new()
var mouse_sensitivity := 0.0022

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	rng.randomize()
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_viewmodel()
	movement_audio = AudioStreamPlayer.new()
	jump_audio = AudioStreamPlayer.new()
	footstep_audio = AudioStreamPlayer.new()
	shot_audio = AudioStreamPlayer.new()
	reload_audio = AudioStreamPlayer.new()
	add_child(movement_audio)
	add_child(jump_audio)
	add_child(footstep_audio)
	add_child(shot_audio)
	add_child(reload_audio)

func _build_viewmodel() -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "ViewWeapon"
	weapon_root.scale = Vector3.ONE * 0.68
	camera.add_child(weapon_root)
	weapon_root.position = Vector3(0.37, -0.32, -0.58)
	var gun_mat := _mat(Color(0.075, 0.095, 0.11), 0.82, 0.22)
	weapon_mesh = MeshInstance3D.new()
	var receiver := BoxMesh.new()
	receiver.size = Vector3(0.14, 0.16, 0.52)
	weapon_mesh.mesh = receiver
	weapon_mesh.material_override = gun_mat
	weapon_root.add_child(weapon_mesh)
	_add_viewmodel_hand(weapon_root, Vector3(0.10, -0.19, 0.12), Vector3(0.20, -0.29, 0.30))
	_add_viewmodel_hand(weapon_root, Vector3(-0.08, -0.08, -0.30), Vector3(-0.14, -0.22, -0.04))
	_add_gun_part(Vector3(0, -0.14, 0.28), Vector3(0.12, 0.13, 0.42), Color("8c4d25")) # wooden stock
	_add_gun_part(Vector3(0, 0.015, -0.31), Vector3(0.13, 0.12, 0.34), Color("a6632c")) # wooden handguard
	_add_gun_part(Vector3(0, -0.17, -0.02), Vector3(0.105, 0.24, 0.13), Color("202426")) # curved magazine upper
	_add_gun_part(Vector3(0, -0.29, -0.075), Vector3(0.09, 0.12, 0.1), Color("303638")) # magazine curve
	_add_gun_part(Vector3(0, -0.17, 0.12), Vector3(0.09, 0.22, 0.13), Color("292c2c")) # pistol grip
	_add_gun_part(Vector3(0, 0.055, -0.58), Vector3(0.055, 0.055, 0.52), Color("252a2a")) # long barrel
	_add_gun_part(Vector3(0, 0.13, -0.12), Vector3(0.075, 0.07, 0.17), Color("202426")) # rear sight
	_add_gun_part(Vector3(0, 0.12, -0.38), Vector3(0.07, 0.1, 0.06), Color("323738")) # front sight
	_add_gun_part(Vector3(0, 0.10, 0.02), Vector3(0.17, 0.08, 0.22), Color("343a39"))
	_add_gun_part(Vector3(0, 0.105, -0.16), Vector3(0.095, 0.035, 0.4), Color("1d2324"))
	_add_gun_part(Vector3(0.075, -0.015, 0.01), Vector3(0.035, 0.09, 0.14), Color("515653"))
	_add_gun_part(Vector3(-0.082, -0.07, 0.02), Vector3(0.022, 0.12, 0.18), Color("a46a39"))
	_add_cylinder_part(weapon_root, Vector3(0.073, -0.03, -0.04), 0.018, 0.1, Color("8a8d82"), 0.84)
	_add_cylinder_part(weapon_root, Vector3(0, 0.055, -0.81), 0.065, 0.035, Color("5e6562"), 0.86)
	_add_weapon_part(weapon_root, Vector3(-0.06, -0.12, -0.04), Vector3(0.075, 0.11, 0.13), Color("1e2424"), 0.42)
	knife_root = Node3D.new()
	knife_root.name = "KnifeView"
	knife_root.scale = Vector3.ONE * 0.68
	knife_root.position = Vector3(0.48, -0.40, -0.63)
	knife_root.rotation = Vector3(0.28, 0.34, -0.52)
	camera.add_child(knife_root)
	_build_knife_viewmodel()
	knife_root.hide()
	grenade_root = Node3D.new()
	grenade_root.name = "GrenadeView"
	grenade_root.scale = Vector3.ONE * 0.68
	grenade_root.position = Vector3(0.32, -0.28, -0.62)
	camera.add_child(grenade_root)
	_build_grenade_model("he")
	grenade_root.hide()
	c4_root = Node3D.new()
	c4_root.name = "C4View"
	c4_root.scale = Vector3.ONE * 0.68
	c4_root.position = Vector3(0.35, -0.28, -0.62)
	camera.add_child(c4_root)
	_add_viewmodel_hand(c4_root, Vector3(0.02, -0.10, 0.08), Vector3(0.12, -0.22, 0.28))
	_add_weapon_part(c4_root, Vector3(0.0, 0.0, -0.06), Vector3(0.31, 0.22, 0.16), Color("303632"), 0.55)
	_add_weapon_part(c4_root, Vector3(0.0, 0.12, -0.06), Vector3(0.22, 0.025, 0.12), Color("8a8c7c"), 0.2)
	for button_index in range(9):
		var key_cap := _add_weapon_part(c4_root, Vector3(-0.075 + float(button_index % 3) * 0.075, 0.045 - float(button_index / 3) * 0.045, -0.145), Vector3(0.045, 0.025, 0.018), Color("b4ad8b"), 0.15)
		key_cap.name = "C4 Key %d" % button_index
	var c4_led := _add_weapon_part(c4_root, Vector3(0.09, 0.09, -0.15), Vector3(0.04, 0.025, 0.018), Color("dd3a28"), 0.05)
	var c4_led_material := _mat(Color("ff3824"), 0.05, 0.3)
	c4_led_material.emission_enabled = true
	c4_led_material.emission = Color("ff1608")
	c4_led.material_override = c4_led_material
	c4_root.hide()
	pistol_root = Node3D.new()
	pistol_root.name = "PistolView"
	pistol_root.scale = Vector3.ONE * 0.62
	pistol_root.position = Vector3(0.37, -0.34, -0.55)
	camera.add_child(pistol_root)
	_add_viewmodel_hand(pistol_root, Vector3(0.08, -0.16, 0.09), Vector3(0.18, -0.27, 0.26))
	_add_weapon_part(pistol_root, Vector3(0, 0, 0), Vector3(0.12, 0.13, 0.34), Color("303638"), 0.7)
	_add_weapon_part(pistol_root, Vector3(0, -0.13, 0.045), Vector3(0.085, 0.2, 0.12), Color("202526"), 0.3)
	_add_weapon_part(pistol_root, Vector3(0, 0.055, -0.23), Vector3(0.045, 0.045, 0.19), Color("555c5d"), 0.85)
	_add_weapon_part(pistol_root, Vector3(0, 0.08, -0.06), Vector3(0.05, 0.035, 0.08), Color("ad6b32"), 0.1)
	var suppressor := _add_cylinder_part(pistol_root, Vector3(0, 0.055, -0.36), 0.042, 0.22, Color("171c1e"), 0.78)
	suppressor.name = "USP Suppressor"
	var glock_slide := _add_weapon_part(pistol_root, Vector3(0, 0.035, -0.045), Vector3(0.135, 0.072, 0.25), Color("191e20"), 0.62)
	glock_slide.name = "Glock Slide"
	var glock_sight := _add_weapon_part(pistol_root, Vector3(0, 0.079, -0.12), Vector3(0.065, 0.018, 0.12), Color("111516"), 0.8)
	glock_sight.name = "Glock Rear Sight"
	_add_weapon_part(pistol_root, Vector3(0.065, 0.015, -0.04), Vector3(0.012, 0.075, 0.23), Color("1c2224"), 0.72)
	_add_weapon_part(pistol_root, Vector3(0, 0.095, -0.07), Vector3(0.065, 0.025, 0.2), Color("171c1e"), 0.68)
	_add_weapon_part(pistol_root, Vector3(0, -0.02, 0.1), Vector3(0.035, 0.11, 0.07), Color("888b82"), 0.8)
	_add_weapon_part(pistol_root, Vector3(-0.072, -0.07, -0.04), Vector3(0.012, 0.11, 0.19), Color("5a5142"), 0.05)
	_add_cylinder_part(pistol_root, Vector3(0, 0.1, -0.15), 0.025, 0.045, Color("111618"), 0.85)
	pistol_root.hide()
	awp_root = Node3D.new()
	awp_root.name = "AWPView"
	awp_root.scale = Vector3.ONE * 0.68
	awp_root.position = Vector3(0.37, -0.33, -0.58)
	camera.add_child(awp_root)
	_add_viewmodel_hand(awp_root, Vector3(0.08, -0.17, 0.12), Vector3(0.18, -0.28, 0.29))
	_add_weapon_part(awp_root, Vector3(0, 0, -0.05), Vector3(0.15, 0.16, 0.65), Color("343d3e"), 0.72)
	_add_weapon_part(awp_root, Vector3(0, -0.08, 0.42), Vector3(0.14, 0.2, 0.42), Color("43554d"), 0.2)
	_add_weapon_part(awp_root, Vector3(0, 0.015, -0.32), Vector3(0.1, 0.105, 0.39), Color("465b50"), 0.25)
	_add_weapon_part(awp_root, Vector3(0, 0.035, -0.89), Vector3(0.075, 0.075, 0.82), Color("242b2d"), 0.86)
	_add_weapon_part(awp_root, Vector3(0, -0.18, -0.12), Vector3(0.105, 0.2, 0.18), Color("262c2e"), 0.62)
	_add_weapon_part(awp_root, Vector3(0, -0.2, 0.13), Vector3(0.09, 0.24, 0.14), Color("23292b"), 0.35)
	_add_weapon_part(awp_root, Vector3(0, -0.08, 0.62), Vector3(0.15, 0.22, 0.06), Color("202526"), 0.38)
	_add_weapon_part(awp_root, Vector3(0, 0.025, -0.1), Vector3(0.2, 0.035, 0.5), Color("66705f"), 0.18)
	_add_cylinder_part(awp_root, Vector3(0, 0.16, -0.1), 0.075, 0.38, Color("20282a"), 0.86)
	_add_cylinder_part(awp_root, Vector3(0, 0.16, -0.28), 0.095, 0.035, Color("899493"), 0.75)
	_add_cylinder_part(awp_root, Vector3(0, 0.16, 0.08), 0.095, 0.035, Color("899493"), 0.75)
	_add_cylinder_part(awp_root, Vector3(0, 0.16, -0.31), 0.064, 0.025, Color("31505a"), 0.45)
	_add_viewmodel_hand(awp_root, Vector3(-0.08, -0.08, -0.34), Vector3(-0.13, -0.21, -0.05))
	awp_root.hide()

func _build_knife_viewmodel() -> void:
	_add_viewmodel_hand(knife_root, Vector3(0.04, -0.09, 0.28), Vector3(0.10, -0.22, 0.52))
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.055
	handle_mesh.bottom_radius = 0.07
	handle_mesh.height = 0.34
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, -0.015, 0.28)
	handle.rotation.x = PI * 0.5
	handle.material_override = _mat(Color("22292a"), 0.12, 0.72)
	knife_root.add_child(handle)
	for band in range(7):
		_add_cylinder_part(knife_root, Vector3(0, -0.015, 0.14 + band * 0.045), 0.071, 0.012, Color("5a5142") if band % 2 == 0 else Color("303735"), 0.05)
	var pommel := MeshInstance3D.new()
	var pommel_mesh := SphereMesh.new()
	pommel_mesh.radius = 0.072
	pommel_mesh.height = 0.12
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0, -0.015, 0.47)
	pommel.material_override = _mat(Color("68685e"), 0.68, 0.35)
	knife_root.add_child(pommel)
	_add_weapon_part(knife_root, Vector3(0, -0.01, 0.035), Vector3(0.22, 0.045, 0.055), Color("858b84"), 0.82)
	var blade := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 0.006, -0.43)
	var blade_points: Array[Vector3] = [Vector3(-0.082, 0.0, -0.05), Vector3(0.082, 0.0, -0.05), Vector3(0.069, 0.0, -0.47), Vector3(0.0, 0.0, -0.91), Vector3(-0.069, 0.0, -0.47)]
	for i in range(blade_points.size()):
		surface.add_vertex(center)
		surface.add_vertex(blade_points[i])
		surface.add_vertex(blade_points[(i + 1) % blade_points.size()])
	var spine_top := Vector3(0, 0.027, -0.43)
	for i in range(blade_points.size()):
		var left := blade_points[i] + Vector3(0, -0.012, 0)
		var right := blade_points[(i + 1) % blade_points.size()] + Vector3(0, -0.012, 0)
		surface.add_vertex(spine_top)
		surface.add_vertex(right)
		surface.add_vertex(left)
	surface.generate_normals()
	blade.mesh = surface.commit()
	blade.material_override = _mat(Color("c5ced0"), 0.9, 0.19)
	knife_root.add_child(blade)
	_add_weapon_part(knife_root, Vector3(0, 0.012, -0.37), Vector3(0.014, 0.006, 0.42), Color("65777c"), 0.85)
	var guard_ring := MeshInstance3D.new()
	var guard_mesh := TorusMesh.new()
	guard_mesh.inner_radius = 0.035
	guard_mesh.outer_radius = 0.055
	guard_ring.mesh = guard_mesh
	guard_ring.position = Vector3(0, 0, 0.05)
	guard_ring.rotation.x = PI * 0.5
	guard_ring.material_override = _mat(Color("858b84"), 0.8, 0.3)
	knife_root.add_child(guard_ring)

func _build_grenade_model(kind: String) -> void:
	for child in grenade_root.get_children():
		child.queue_free()
	_add_viewmodel_hand(grenade_root, Vector3(0.02, -0.06, 0.06), Vector3(0.12, -0.20, 0.25))
	var colors := {"he": Color("334b35"), "smoke": Color("56665a"), "flash": Color("b3a777"), "molotov": Color("79462f")}
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.105
	shell_mesh.height = 0.27
	shell.mesh = shell_mesh
	shell.position = Vector3(0, 0.02, 0)
	shell.material_override = _mat(colors.get(kind, Color("334b35")), 0.22, 0.58)
	grenade_root.add_child(shell)
	for rib in range(5):
		var torus := MeshInstance3D.new()
		var torus_mesh := TorusMesh.new()
		torus_mesh.inner_radius = 0.092
		torus_mesh.outer_radius = 0.108
		torus.mesh = torus_mesh
		torus.position = Vector3(0, -0.075 + rib * 0.045, 0)
		torus.material_override = _mat(Color("879083"), 0.5, 0.4)
		grenade_root.add_child(torus)
	_add_weapon_part(grenade_root, Vector3(0, 0.15, 0), Vector3(0.105, 0.09, 0.105), Color("85877a"), 0.65)
	_add_weapon_part(grenade_root, Vector3(0.105, 0.13, 0.01), Vector3(0.17, 0.025, 0.045), Color("6c706a"), 0.72)
	var pin := MeshInstance3D.new()
	var pin_mesh := TorusMesh.new()
	pin_mesh.inner_radius = 0.025
	pin_mesh.outer_radius = 0.036
	pin.mesh = pin_mesh
	pin.position = Vector3(0.12, 0.14, 0.04)
	pin.rotation.z = PI * 0.5
	pin.material_override = _mat(Color("bdc0b1"), 0.9, 0.25)
	grenade_root.add_child(pin)

func _add_viewmodel_hand(parent: Node3D, grip: Vector3, forearm_end: Vector3) -> void:
	# A compact first-person sleeve, glove and fingers make every held item feel held.
	var glove := _mat(Color("303633"), 0.04, 0.88)
	var sleeve := _mat(Color("78816a"), 0.0, 0.94)
	_add_weapon_part(parent, forearm_end, Vector3(0.16, 0.18, 0.30), Color("78816a"), 0.0)
	var cuff := _add_weapon_part(parent, forearm_end + Vector3(0.0, 0.02, -0.12), Vector3(0.17, 0.19, 0.08), Color("353d38"), 0.0)
	cuff.material_override = sleeve
	var palm := _add_weapon_part(parent, grip, Vector3(0.14, 0.12, 0.16), Color("303633"), 0.0)
	palm.material_override = glove
	for finger in range(3):
		var digit := _add_weapon_part(parent, grip + Vector3(-0.045 + finger * 0.045, -0.045, -0.08), Vector3(0.035, 0.045, 0.12), Color("303633"), 0.0)
		digit.material_override = glove
	var thumb := _add_weapon_part(parent, grip + Vector3(-0.085, 0.005, -0.02), Vector3(0.05, 0.05, 0.12), Color("303633"), 0.0)
	thumb.rotation.z = -0.45
	thumb.material_override = glove

func _add_gun_part(pos: Vector3, size: Vector3, color: Color) -> void:
	_add_weapon_part(weapon_root, pos, size, color, 0.65)

func _add_weapon_part(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metallic: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = pos
	part.material_override = _mat(color, metallic, 0.42)
	parent.add_child(part)
	return part

func _add_cylinder_part(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color, metallic: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	part.mesh = cylinder
	part.position = pos
	part.rotation.x = PI * 0.5
	part.material_override = _mat(color, metallic, 0.28)
	parent.add_child(part)
	return part

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -1.52, 1.52)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_set_scoping(event.pressed and current_weapon == "awp")
	if event is InputEventKey and event.pressed and not event.echo:
		if buy_menu_open:
			return
		if event.keycode == KEY_5 and has_c4 and not buy_menu_open:
			equip_c4()
		elif event.keycode == KEY_R:
			_reload()
		elif reloading:
			return
		elif event.keycode == KEY_1:
			equip_primary()
		elif event.keycode == KEY_2:
			equip_pistol()
		elif event.keycode == KEY_3 or event.keycode == KEY_Q:
			equip_knife()
		elif event.keycode == KEY_4:
			_cycle_grenade()

func _physics_process(delta: float) -> void:
	if movement_locked: return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if reloading:
		reload_time -= delta
		var reload_duration := 1.35 if current_weapon == "pistol" else 2.4 if current_weapon == "awp" else 1.65
		var t := 1.0 - clampf(reload_time / reload_duration, 0.0, 1.0)
		var reload_root := _active_weapon_root()
		reload_root.position.y = _weapon_resting_y() - sin(t * PI) * 0.22
		reload_root.rotation.x = sin(t * PI) * 0.32
		if reload_time <= 0.0:
			if current_weapon == "pistol":
				var pistol_amount := mini(12 - pistol_ammo, pistol_reserve)
				pistol_ammo += pistol_amount
				pistol_reserve -= pistol_amount
			elif current_weapon == "awp":
				var awp_amount := mini(5 - awp_ammo, awp_reserve)
				awp_ammo += awp_amount
				awp_reserve -= awp_amount
			else:
				var rifle_amount := mini(MAG_SIZE - ammo, reserve)
				ammo += rifle_amount
				reserve -= rifle_amount
			reloading = false
			weapon_root.position = Vector3(0.37, -0.32, -0.58)
			weapon_root.rotation = Vector3.ZERO
			pistol_root.position = Vector3(0.37, -0.34, -0.55)
			pistol_root.rotation = Vector3.ZERO
			awp_root.position = Vector3(0.37, -0.33, -0.58)
			awp_root.rotation = Vector3.ZERO
			reloaded.emit()
			_play_tone(680, 0.1, 0.08, 2)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if Input.is_key_pressed(KEY_SPACE):
		jump_buffer_left = 0.12
	else:
		jump_buffer_left = maxf(0.0, jump_buffer_left - delta)
	crouched = Input.is_key_pressed(KEY_CTRL)
	var walking := Input.is_key_pressed(KEY_SHIFT)
	var target_speed := CROUCH_SPEED if crouched else WALK_SPEED if walking else RUN_SPEED
	if is_on_floor():
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		if horizontal_speed > 0.0:
			var drop := maxf(horizontal_speed, STOP_SPEED) * GROUND_FRICTION * delta
			var new_speed := maxf(0.0, horizontal_speed - drop)
			velocity.x *= new_speed / horizontal_speed
			velocity.z *= new_speed / horizontal_speed
	if wish_dir != Vector3.ZERO:
		var wish_speed := target_speed if is_on_floor() else AIR_STRAFE_SPEED
		_accelerate(wish_dir, wish_speed, GROUND_ACCEL if is_on_floor() else AIR_ACCEL, delta)
	if not is_on_floor():
		var air_velocity := Vector2(velocity.x, velocity.z)
		if air_velocity.length() > AIR_SPEED_CAP:
			air_velocity = air_velocity.normalized() * AIR_SPEED_CAP
			velocity.x = air_velocity.x
			velocity.z = air_velocity.y
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2
	if jump_buffer_left > 0.0 and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_buffer_left = 0.0
		_play_tone(420, 0.075, 0.12, 3)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0 and not reloading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire()
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var active_root := _active_weapon_root()
	if horizontal_speed > 0.5 and is_on_floor():
		bob_time += delta * (12.0 if walking else 16.0)
		var bob_scale := 0.65 if current_weapon == "awp" else 1.0
		active_root.position.y = _weapon_resting_y() + sin(bob_time) * 0.018 * bob_scale
		active_root.position.x = move_toward(active_root.position.x, (0.37 if current_weapon != "knife" else 0.36) + sin(bob_time * 0.5) * 0.012 * bob_scale, delta * 2.0)
		active_root.rotation.z = lerpf(active_root.rotation.z, (-0.52 if current_weapon == "knife" else 0.0) + cos(bob_time) * 0.018 * bob_scale, delta * 5.0)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			_play_tone(95 if crouched else 125, 0.035, 0.035, 4)
			footstep_timer = 0.43 if crouched else 0.36 if walking else 0.27
	else:
		active_root.position.y = move_toward(active_root.position.y, _weapon_resting_y(), delta * 0.35)
		active_root.position.x = move_toward(active_root.position.x, 0.37, delta * 2.0)
		active_root.rotation.z = move_toward(active_root.rotation.z, -0.52 if current_weapon == "knife" else 0.0, delta * 4.0)
	var target_height := 1.15 if crouched else 1.65
	var movement_bob := sin(bob_time * 2.0) * 0.025 if horizontal_speed > 0.5 and is_on_floor() else 0.0
	camera.position.y = move_toward(camera.position.y, target_height + movement_bob, delta * 5.5)
	var capsule := collision_shape.shape as CapsuleShape3D
	capsule.height = 1.2 if crouched else 1.8
	collision_shape.position.y = capsule.height * 0.5
	active_root.position.z = move_toward(active_root.position.z, -0.55 if current_weapon == "pistol" else -0.58, delta * 1.8)
	active_root.rotation.x = move_toward(active_root.rotation.x, 0.28 if current_weapon == "knife" else 0.0, delta * 2.5)

func _fire() -> void:
	if current_weapon == "c4": return
	if current_weapon == "grenade":
		if int(grenades.get(grenade_kind, 0)) <= 0:
			_play_tone(180, 0.07, 0.08, 1)
			return
		grenades[grenade_kind] = int(grenades[grenade_kind]) - 1
		fire_cooldown = 0.65
		grenade_root.rotation.x = -0.24
		grenade_thrown.emit(grenade_kind, camera.global_position - camera.global_transform.basis.z * 0.65, -camera.global_transform.basis.z)
		_play_tone(230, 0.07, 0.08, 1)
		equip_primary()
		return
	if knife_equipped:
		fire_cooldown = 0.48
		knife_root.rotation.x = -0.34
		_play_tone(260, 0.08, 0.08, 1)
		var knife_ray := camera.get_world_3d().direct_space_state
		var knife_query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * 2.2)
		var knife_hit := knife_ray.intersect_ray(knife_query)
		if not knife_hit.is_empty():
			var target: Node3D = knife_hit.collider
			if target.is_in_group("bots") or target.is_in_group("online_players"):
				fired.emit(target, true)
		return
	var using_pistol := current_weapon == "pistol"
	var using_awp := current_weapon == "awp"
	var selected_ammo := pistol_ammo if using_pistol else awp_ammo if using_awp else ammo
	if selected_ammo <= 0:
		_play_tone(180, 0.07, 0.08, 1)
		return
	if using_pistol:
		pistol_ammo -= 1
	elif using_awp:
		awp_ammo -= 1
	else:
		ammo -= 1
	fire_cooldown = 0.28 if using_pistol else 0.95 if using_awp else FIRE_INTERVAL
	var active_root := _active_weapon_root()
	active_root.position.z = -0.50 if using_pistol else -0.53
	active_root.rotation.x = -0.045 if using_pistol else -0.035
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * 120.0)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var target: Node3D = hit.collider
		if target.is_in_group("bots") or target.is_in_group("online_players"):
			fired.emit(target, hit.position.y > target.global_position.y + 1.48)
	_play_tone(rng.randf_range(190.0, 235.0) if using_pistol else rng.randf_range(100.0, 130.0) if using_awp else rng.randf_range(120.0, 150.0), 0.055 if using_pistol else 0.1 if using_awp else 0.06, 0.09 if using_pistol else 0.15 if using_awp else 0.12, 1)

func _reload() -> void:
	if reloading or knife_equipped or current_weapon == "grenade":
		return
	if current_weapon == "pistol":
		if pistol_ammo >= 12 or pistol_reserve <= 0: return
	elif current_weapon == "awp":
		if awp_ammo >= 5 or awp_reserve <= 0: return
	else:
		if ammo >= MAG_SIZE or reserve <= 0: return
	reloading = true
	reload_time = 1.35 if current_weapon == "pistol" else 2.4 if current_weapon == "awp" else 1.65
	_play_tone(310, 0.12, 0.08, 2)

func equip_knife() -> void:
	_set_scoping(false)
	current_weapon = "knife"
	knife_equipped = true
	weapon_root.hide()
	knife_root.show()
	pistol_root.hide()
	awp_root.hide()
	grenade_root.hide()
	c4_root.hide()

func equip_primary() -> void:
	if primary_weapon == "awp": equip_awp()
	elif primary_weapon == "rifle": equip_rifle()

func equip_rifle() -> void:
	_set_scoping(false)
	current_weapon = "rifle"
	knife_equipped = false
	weapon_root.show()
	weapon_mesh.show()
	knife_root.hide()
	pistol_root.hide()
	awp_root.hide()
	grenade_root.hide()
	c4_root.hide()

func equip_pistol(model: String = "") -> void:
	_set_scoping(false)
	if not model.is_empty():
		pistol_model = "glock" if model.to_lower().contains("glock") else "usp"
	current_weapon = "pistol"
	knife_equipped = false
	weapon_root.hide()
	knife_root.hide()
	pistol_root.show()
	var suppressor := pistol_root.get_node_or_null("USP Suppressor") as MeshInstance3D
	if is_instance_valid(suppressor): suppressor.visible = pistol_model == "usp"
	var glock_slide := pistol_root.get_node_or_null("Glock Slide") as MeshInstance3D
	var glock_sight := pistol_root.get_node_or_null("Glock Rear Sight") as MeshInstance3D
	if is_instance_valid(glock_slide): glock_slide.visible = pistol_model == "glock"
	if is_instance_valid(glock_sight): glock_sight.visible = pistol_model == "glock"
	awp_root.hide()
	grenade_root.hide()
	c4_root.hide()

func equip_awp() -> void:
	_set_scoping(false)
	current_weapon = "awp"
	knife_equipped = false
	weapon_root.hide()
	knife_root.hide()
	pistol_root.hide()
	awp_root.show()
	grenade_root.hide()
	c4_root.hide()

func equip_grenade(kind: String) -> void:
	if int(grenades.get(kind, 0)) <= 0:
		return
	_set_scoping(false)
	current_weapon = "grenade"
	knife_equipped = false
	grenade_kind = kind
	weapon_root.hide()
	knife_root.hide()
	pistol_root.hide()
	awp_root.hide()
	_build_grenade_model(kind)
	grenade_root.show()
	c4_root.hide()

func _cycle_grenade() -> void:
	var order := ["he", "flash", "smoke", "molotov"]
	var owned: Array[String] = []
	for kind in order:
		if int(grenades.get(kind, 0)) > 0:
			owned.append(kind)
	if owned.is_empty():
		return
	var current_index := owned.find(grenade_kind) if current_weapon == "grenade" else -1
	equip_grenade(owned[(current_index + 1) % owned.size()])

func equip_c4() -> void:
	if not has_c4: return
	_set_scoping(false)
	current_weapon = "c4"
	knife_equipped = false
	weapon_root.hide()
	knife_root.hide()
	pistol_root.hide()
	awp_root.hide()
	grenade_root.hide()
	c4_root.show()

func _set_scoping(enabled: bool) -> void:
	if current_weapon != "awp": enabled = false
	if is_scoping == enabled: return
	is_scoping = enabled
	camera.fov = 28.0 if enabled else 75.0
	scope_changed.emit(enabled)

func _accelerate(wish_dir: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	var current_speed := Vector2(velocity.x, velocity.z).dot(Vector2(wish_dir.x, wish_dir.z))
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(add_speed, acceleration * wish_speed * delta)
	velocity.x += wish_dir.x * accel_speed
	velocity.z += wish_dir.z * accel_speed

func _active_weapon_root() -> Node3D:
	if current_weapon == "c4": return c4_root
	if current_weapon == "grenade": return grenade_root
	if current_weapon == "knife": return knife_root
	if current_weapon == "pistol": return pistol_root
	if current_weapon == "awp": return awp_root
	return weapon_root

func _weapon_resting_y() -> float:
	if current_weapon == "c4": return -0.28
	if current_weapon == "grenade": return -0.28
	if current_weapon == "pistol": return -0.34
	if current_weapon == "awp": return -0.33
	return -0.32

func _play_tone(frequency: float, duration: float, volume: float, channel: int = 0) -> void:
	var rate := 22050
	var samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var env := 1.0 - float(i) / float(samples)
		var sample := sin(phase) * env * volume
		bytes.encode_s16(i * 2, int(sample * 32767.0))
		phase += TAU * frequency / float(rate)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	var channel_player := movement_audio
	if channel == 1:
		channel_player = shot_audio
	elif channel == 2:
		channel_player = reload_audio
	elif channel == 3:
		channel_player = jump_audio
	elif channel == 4:
		channel_player = footstep_audio
	channel_player.stream = stream
	channel_player.play()

func play_damage_sound() -> void:
	_play_tone(78.0, 0.18, 0.18, 1)

func play_remote_shot_sound() -> void:
	_play_tone(rng.randf_range(105.0, 145.0), 0.045, 0.035, 1)
