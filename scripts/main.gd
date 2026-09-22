extends Node2D
## Slice A test room: flat arena, hero, wave-1 spawner (agents x6), HUD, game over -> retry.

signal wave_cleared
signal game_over

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var score := 0
var kills := 0
var wave := 1
var game_ended := false
var wave_cleared_done := false
var spawning_done := false
var spawned_count := 0
var wave_enemies: Array = []
var player: Player
var game_over_layer: CanvasLayer

var _spawn_t: float = Feel.WAVE_SPAWN_INTERVAL
var _hud_lives: Label
var _hud_score: Label
var _hud_kills: Label
var _hud_wave: Label


func _ready() -> void:
	_build_room()
	_build_player()
	_build_hud()
	_build_game_over()


func _physics_process(delta: float) -> void:
	if game_ended:
		return
	_tick_spawner(delta)
	_maybe_clear_wave()


func _process(_delta: float) -> void:
	if _hud_lives == null:
		return
	_hud_lives.text = "LIVES %d" % maxi(player.lives, 0)
	_hud_score.text = "SCORE %d" % score
	_hud_kills.text = "KILLS %d" % kills
	_hud_wave.text = "WAVE %d CLEARED" % wave if wave_cleared_done else "WAVE %d" % wave


# -- room --

func _build_room() -> void:
	_block(Feel.GROUND_RECT, Feel.COLOR_GROUND)
	for r in Feel.PLATFORMS:
		_block(r, Feel.COLOR_PLATFORM)
	_block(Feel.WALL_LEFT_RECT, Feel.COLOR_WORLD)
	_block(Feel.WALL_RIGHT_RECT, Feel.COLOR_WORLD)


func _block(r: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("world")
	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	cs.shape = box
	body.add_child(cs)
	body.position = r.get_center()
	add_child(body)
	var rect := ColorRect.new()
	rect.position = r.position
	rect.size = r.size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


# -- actors --

func _build_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.spawn_point = Feel.SPAWN_POINT
	add_child(player)
	player.died.connect(_on_player_died)


func _tick_spawner(delta: float) -> void:
	if spawning_done:
		return
	_spawn_t += delta
	if spawned_count < Feel.WAVE1_AGENT_COUNT and _spawn_t >= Feel.WAVE_SPAWN_INTERVAL:
		_spawn_t = 0.0
		_spawn_agent()
	if spawned_count >= Feel.WAVE1_AGENT_COUNT:
		spawning_done = true


func _spawn_agent() -> void:
	var e: EnemyAgent = ENEMY_SCENE.instantiate()
	e.target = player
	e.bullet_parent = self
	e.position = Vector2(Feel.WAVE_SPAWN_X - float(spawned_count) * Feel.WAVE_SPAWN_SPACING, Feel.WAVE_SPAWN_Y)
	add_child(e)
	wave_enemies.append(e)
	e.died.connect(_on_enemy_died.bind(e))
	spawned_count += 1


func _on_enemy_died(points: int, e: EnemyAgent) -> void:
	score += points
	kills += 1
	wave_enemies.erase(e)


func _maybe_clear_wave() -> void:
	if spawning_done and not wave_cleared_done and wave_enemies.is_empty():
		wave_cleared_done = true
		wave_cleared.emit()


# -- death / game over / retry --

func _on_player_died(lives_left: int) -> void:
	if game_ended:
		return
	if lives_left > 0:
		await get_tree().create_timer(Feel.RESPAWN_DELAY).timeout
		if game_ended or player == null or not is_instance_valid(player):
			return
		player.respawn(player.spawn_point)
	else:
		_end_game()


func _end_game() -> void:
	game_ended = true
	game_over_layer.visible = true
	game_over.emit()


func _unhandled_input(event: InputEvent) -> void:
	if game_ended and event.is_action_pressed("retry"):
		if get_tree().current_scene != null:
			get_tree().reload_current_scene()


# -- HUD --

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_lives = _hud_label(layer, Vector2(16, 12))
	_hud_score = _hud_label(layer, Vector2(16, 40))
	_hud_kills = _hud_label(layer, Vector2(16, 68))
	_hud_wave = _hud_label(layer, Vector2(790, 12))


func _hud_label(layer: CanvasLayer, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 20)
	layer.add_child(l)
	return l


func _build_game_over() -> void:
	game_over_layer = CanvasLayer.new()
	game_over_layer.layer = 10
	game_over_layer.visible = false
	add_child(game_over_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_layer.add_child(dim)
	var lbl := Label.new()
	lbl.text = "GAME OVER\nPRESS R TO RETRY"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_layer.add_child(lbl)
