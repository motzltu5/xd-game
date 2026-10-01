extends CharacterBody3D

const BOT_BODY_SCALE := 1.392

var player: CharacterBody3D
var game: Node
var teammate := false
var hp := 100
var shot_timer := 1.0
var strafe_timer := 0.0
var strafe_side := 1.0
var gun: MeshInstance3D
var body_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var character_built := false
var active_target: Node3D
var style := "DUELIST"
var move_speed := 7.2
var preferred_range := 25.0
var strafe_min := 0.55
var strafe_max := 1.4
var shot_min := 0.75
var shot_max := 1.25
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var walk_cycle := 0.0
var defuse_progress := 0.0

func setup(target: CharacterBody3D, game_root: Node, is_teammate: bool, bot_style: String = "DUELIST") -> void:
	player = target
	game = game_root
	teammate = is_teammate
	style = bot_style
	rng.randomize()
	match style:
		"RUSHER", "SPRINTER", "BREACHER":
			move_speed = 10.5
			preferred_range = 16.0
			shot_min = 0.58
			shot_max = 0.92
		"ANCHOR", "GUARD", "SENTINEL":
			move_speed = 5.4
			preferred_range = 34.0
			shot_min = 0.8
			shot_max = 1.5
		"FLANKER", "HUNTER", "SCOUT":
			move_speed = 8.8
			preferred_range = 27.0
			strafe_min = 0.3
			strafe_max = 0.85
			shot_min = 0.65
			shot_max = 1.1
	move_speed *= rng.randf_range(0.9, 1.12)
	preferred_range += rng.randf_range(-1.2, 1.2)
	strafe_side = -1.0 if rng.randf() < 0.5 else 1.0
	shot_min *= rng.randf_range(0.92, 1.12)
	shot_max *= rng.randf_range(0.9, 1.15)
	_build_character()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	scale = Vector3.ONE * BOT_BODY_SCALE
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6 / BOT_BODY_SCALE
	capsule.height = 2.7 / BOT_BODY_SCALE
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5
	add_child(collision)

func _build_character() -> void:
	if character_built: return
	character_built = true
	var outfit := Color("416b72") if teammate else Color("a65c39")
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = outfit
	body_mat.roughness = 0.72
	_add_part("Armored vest", Vector3(0, 0.96, 0), Vector3(0.68, 0.72, 0.38), outfit)
	_add_part("Chest plate", Vector3(0, 0.98, -0.205), Vector3(0.42, 0.4, 0.045), Color("303b3b"))
	_add_part("Head", Vector3(0, 1.66, 0), Vector3(0.42, 0.42, 0.4), Color("c49a78"))
	_add_part("Helmet", Vector3(0, 1.84, -0.015), Vector3(0.47, 0.2, 0.44), Color("3c4a45"))
	left_leg = _add_part("Left leg", Vector3(-0.19, 0.38, 0), Vector3(0.24, 0.65, 0.32), Color("30383a"))
	right_leg = _add_part("Right leg", Vector3(0.19, 0.38, 0), Vector3(0.24, 0.65, 0.32), Color("30383a"))
	_add_part("Left boot", Vector3(-0.19, 0.08, -0.045), Vector3(0.27, 0.16, 0.42), Color("171c1d"))
	_add_part("Right boot", Vector3(0.19, 0.08, -0.045), Vector3(0.27, 0.16, 0.42), Color("171c1d"))
	_add_part("Left knee pad", Vector3(-0.19, 0.48, -0.17), Vector3(0.27, 0.2, 0.08), Color("59615a"))
	_add_part("Right knee pad", Vector3(0.19, 0.48, -0.17), Vector3(0.27, 0.2, 0.08), Color("59615a"))
	_add_part("Belt", Vector3(0, 0.67, -0.015), Vector3(0.58, 0.13, 0.4), Color("343b36"))
	_add_part("Left pouch", Vector3(-0.32, 0.72, -0.19), Vector3(0.16, 0.2, 0.13), Color("5a6255"))
	_add_part("Right pouch", Vector3(0.32, 0.72, -0.19), Vector3(0.16, 0.2, 0.13), Color("5a6255"))
	_add_part("Shoulder pad L", Vector3(-0.4, 1.34, 0), Vector3(0.28, 0.19, 0.3), Color("3d4943"))
	_add_part("Shoulder pad R", Vector3(0.4, 1.34, 0), Vector3(0.28, 0.19, 0.3), Color("3d4943"))
	_add_part("Harness strap", Vector3(0.12, 1.08, -0.22), Vector3(0.09, 0.62, 0.05), Color("c1a268"))
	_add_part("Radio", Vector3(-0.32, 1.16, 0.22), Vector3(0.14, 0.31, 0.12), Color("252c2a"))
	_add_part("Face visor", Vector3(0, 1.66, -0.205), Vector3(0.32, 0.1, 0.035), Color("4b6868"))
	_add_part("Ear protection L", Vector3(-0.22, 1.65, 0), Vector3(0.09, 0.2, 0.22), Color("252d2c"))
	_add_part("Ear protection R", Vector3(0.22, 1.65, 0), Vector3(0.09, 0.2, 0.22), Color("252d2c"))
	_add_part("Back plate", Vector3(0, 1.0, 0.22), Vector3(0.42, 0.48, 0.08), Color("303a38"))
	_add_part("Shoulder insignia", Vector3(-0.42, 1.34, -0.16), Vector3(0.1, 0.12, 0.025), Color("d7b35e" if teammate else "c66b4e"))
	_add_part("Utility pouch L", Vector3(-0.2, 0.73, -0.24), Vector3(0.14, 0.18, 0.09), Color("77735d"))
	_add_part("Utility pouch R", Vector3(0.2, 0.73, -0.24), Vector3(0.14, 0.18, 0.09), Color("77735d"))
	_add_part("Rifle optic", Vector3(0.37, 1.18, -0.52), Vector3(0.09, 0.1, 0.14), Color("252c2c"))
	_add_part("Optic lens", Vector3(0.37, 1.18, -0.6), Vector3(0.055, 0.055, 0.018), Color("547a78"))
	_add_part("Radio antenna", Vector3(-0.36, 1.42, 0.2), Vector3(0.025, 0.42, 0.025), Color("1c2322"))
	left_arm = _add_part("Left arm", Vector3(-0.45, 1.05, -0.04), Vector3(0.2, 0.62, 0.22), outfit)
	right_arm = _add_part("Right arm", Vector3(0.45, 1.05, -0.18), Vector3(0.2, 0.62, 0.22), outfit)
	gun = _add_part("Rifle", Vector3(0.37, 1.05, -0.52), Vector3(0.12, 0.12, 0.7), Color("202627"))
	_add_part("Wood handguard", Vector3(0.37, 1.05, -0.58), Vector3(0.14, 0.14, 0.34), Color("8d542c"))
	_add_part("Rifle barrel", Vector3(0.37, 1.05, -1.0), Vector3(0.055, 0.055, 0.42), Color("171c1e"))
	_add_part("Rifle magazine", Vector3(0.37, 0.87, -0.52), Vector3(0.1, 0.3, 0.14), Color("252b2c"))
	_add_part("Wood stock", Vector3(0.37, 1.05, -0.12), Vector3(0.12, 0.15, 0.28), Color("81502d"))
	_add_part("Muzzle", Vector3(0.37, 1.05, -1.24), Vector3(0.08, 0.08, 0.1), Color("111617"))
	name_label()

func name_label() -> void:
	var label := Label3D.new()
	label.text = ("ALLY  " if teammate else "BOT  ") + style
	label.position = Vector3(0, 2.1, 0)
	label.font_size = 36
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("7cd4d8") if teammate else Color("f2c66d")
	add_child(label)

func _add_part(part_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	if part_name == "Head":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		part.mesh = sphere
		part.scale = size
	elif part_name == "Armored vest":
		var vest := CapsuleMesh.new()
		vest.radius = 0.34
		vest.height = 0.82
		part.mesh = vest
	else:
		var box := BoxMesh.new()
		box.size = size
		part.mesh = box
	part.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.24 if part_name == "Rifle" else 0.05
	material.roughness = 0.7
	part.material_override = material
	add_child(part)
	return part

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(game): return
	if not bool(game.get("round_live")): return
	if not teammate and str(game.get("mode")) == "5V5" and bool(game.get("bomb_planted")):
		var bomb_position: Vector3 = game.get("bomb_position")
		var to_bomb := bomb_position - global_position
		to_bomb.y = 0.0
		if to_bomb.length() > 2.2:
			var move_direction := to_bomb.normalized()
			velocity.x = move_toward(velocity.x, move_direction.x * move_speed, delta * 9.0)
			velocity.z = move_toward(velocity.z, move_direction.z * move_speed, delta * 9.0)
			velocity.y -= 22.0 * delta
			look_at(Vector3(bomb_position.x, global_position.y, bomb_position.z), Vector3.UP)
			move_and_slide()
			_animate_walk(delta)
			defuse_progress = 0.0
		else:
			velocity = Vector3.ZERO
			defuse_progress += delta
			if defuse_progress >= 10.0:
				game.call("bot_defused_bomb", self)
		return
	var target := _choose_target()
	if target == null: return
	var target_pos := target.global_position
	var to_target := target_pos - global_position
	var distance := to_target.length()
	var direction := to_target.normalized()
	var desired_range := minf(preferred_range, 5.0) if teammate else preferred_range
	if distance > desired_range:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, delta * 9.0)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, delta * 9.0)
	else:
		strafe_timer -= delta
		if strafe_timer <= 0:
			strafe_timer = rng.randf_range(strafe_min, strafe_max)
			strafe_side = -strafe_side
		var side := Vector3(-direction.z, 0, direction.x) * strafe_side
		velocity.x = move_toward(velocity.x, side.x * 3.0, delta * 9.0)
		velocity.z = move_toward(velocity.z, side.z * 3.0, delta * 9.0)
	velocity.y -= 22.0 * delta
	if direction.length() > 0.1:
		look_at(Vector3(target_pos.x, global_position.y, target_pos.z), Vector3.UP)
	move_and_slide()
	_animate_walk(delta)
	shot_timer -= delta
	if not teammate and shot_timer <= 0.0 and distance < 42.0:
		shot_timer = rng.randf_range(shot_min, shot_max)
		_shoot_target(target)
	elif teammate and shot_timer <= 0.0 and distance < 42.0:
		shot_timer = rng.randf_range(shot_min, shot_max)
		_shoot_target(target)

func _animate_walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.2:
		walk_cycle += delta * speed * 3.2
	var swing := sin(walk_cycle) * minf(speed / 3.0, 1.0) * 0.48
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.65
	right_arm.rotation.x = swing * 0.65

func _choose_target() -> Node3D:
	if _is_valid_opponent(active_target) and _has_line_of_sight(active_target):
		return active_target
	active_target = null
	var candidates: Array = []
	var mode_name := str(game.get("mode"))
	if teammate:
		candidates = get_tree().get_nodes_in_group("bots")
	elif mode_name == "5V5":
		candidates = get_tree().get_nodes_in_group("allies")
		candidates.append_array(get_tree().get_nodes_in_group("player"))
	elif mode_name == "DEATHMATCH":
		candidates = get_tree().get_nodes_in_group("bots")
		candidates.append_array(get_tree().get_nodes_in_group("player"))
	else:
		candidates = get_tree().get_nodes_in_group("player")
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in candidates:
		if not (candidate is Node3D) or candidate == self or not is_instance_valid(candidate):
			continue
		if mode_name == "5V5" and candidate.is_in_group("player") and int(game.get("health")) <= 0:
			continue
		if candidate is CharacterBody3D and candidate.has_method("take_damage") and int(candidate.get("hp")) <= 0:
			continue
		var candidate_node := candidate as Node3D
		if not _has_line_of_sight(candidate_node): continue
		var distance: float = global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	active_target = nearest
	return active_target

func _has_line_of_sight(target: Node3D) -> bool:
	if not is_instance_valid(target): return false
	var start := global_position + Vector3.UP * 1.2
	var finish := target.global_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target

func _is_valid_opponent(candidate: Variant) -> bool:
	if not is_instance_valid(candidate): return false
	if not (candidate is Node3D): return false
	var candidate_node := candidate as Node3D
	if candidate_node is CharacterBody3D and candidate_node.has_method("take_damage") and int(candidate_node.get("hp")) <= 0:
		return false
	if teammate: return candidate_node.is_in_group("bots")
	var mode_name := str(game.get("mode"))
	if mode_name == "5V5":
		if candidate_node.is_in_group("player") and int(game.get("health")) <= 0:
			return false
		return candidate_node.is_in_group("allies") or candidate_node.is_in_group("player")
	if mode_name == "DEATHMATCH":
		return candidate_node.is_in_group("bots") or candidate_node.is_in_group("player")
	return candidate_node.is_in_group("player")

func _shoot_target(target: Node3D) -> void:
	if not is_instance_valid(target): return
	if is_instance_valid(player): player.call("play_remote_shot_sound")
	var start := global_position + Vector3(0, 1.25, 0)
	var aim_point := target.global_position + Vector3(0, 1.45, 0)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start, aim_point)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty() or hit.collider != target: return
	if target.is_in_group("player"):
		var headshot: bool = hit.position.y > target.global_position.y + 1.48
		game.call("player_hit", rng.randi_range(7, 12), self, headshot, "AK-47")
	elif target.is_in_group("allies") or target.is_in_group("bots"):
		var headshot: bool = hit.position.y > target.global_position.y + 1.48
		var damage := 100 if headshot else 50
		game.call("record_bot_damage", self, target, damage, headshot)
		target.call("take_damage", damage, headshot, false, self)

func take_damage(amount: int, headshot: bool, player_kill: bool = false, killer: Node3D = null) -> void:
	hp -= amount
	if hp <= 0:
		if is_instance_valid(game):
			if player_kill:
				game.call("bot_killed", self, headshot)
			else:
				game.call("bot_died", self, teammate, killer, headshot)
		queue_free()
