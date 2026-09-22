class_name EnemyAgent
extends CharacterBody2D
## Roster v1 "agent": hp 1, advance + stop-and-shoot.
## State machine: ADVANCE -> STOP -> SHOOT (fires one bullet at the player) -> ADVANCE.
## Its bullet one-hits the player.

signal died(points: int)

enum State { ADVANCE, STOP, SHOOT }

var state: State = State.ADVANCE
var hp: int = Feel.ENEMY_HP
var speed: float = Feel.ENEMY_SPEED
var points: int = Feel.SCORE_PER_KILL
var target: Node2D
var bullet_parent: Node
var vis: Node2D

var _state_t := 0.0
var _flash := 0.0
var _facing := 1


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1 << 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Feel.ENEMY_SIZE
	shape.shape = box
	add_child(shape)
	vis = Node2D.new()
	add_child(vis)
	vis.add_child(Feel.make_sprite(Feel.TEX_ENEMY_AGENT, Feel.ENEMY_SIZE * Feel.SPRITE_BLEED, Feel.COLOR_ENEMY))


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	_state_t += delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + Feel.GRAVITY * delta, Feel.MAX_FALL_SPEED)
	match state:
		State.ADVANCE:
			_do_advance()
		State.STOP:
			_do_stop()
		State.SHOOT:
			_do_shoot()
	if _flash > 0.0:
		_flash -= delta
		vis.modulate = Feel.COLOR_FLASH
	else:
		vis.modulate = Color.WHITE
	move_and_slide()
	vis.scale = Vector2(float(_face_dir()), 1.0)


func take_hit(dmg: int) -> void:
	if hp <= 0:
		return
	hp -= dmg
	_flash = Feel.HIT_FLASH_TIME
	if hp <= 0:
		_die()


# -- state machine --

func _do_advance() -> void:
	velocity.x = signf(_dx_to_target()) * speed
	if absf(_dx_to_target()) <= Feel.ENEMY_STOP_RANGE:
		_enter(State.STOP)


func _do_stop() -> void:
	velocity.x = 0.0
	if _state_t >= Feel.ENEMY_STOP_TIME:
		_enter(State.SHOOT)


func _do_shoot() -> void:
	velocity.x = 0.0
	if _state_t >= Feel.ENEMY_SHOOT_TIME:
		_enter(State.ADVANCE)


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.SHOOT:
		_fire()


func _dx_to_target() -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	return target.global_position.x - global_position.x


func _face_dir() -> int:
	var dx := _dx_to_target()
	if dx < 0.0:
		_facing = -1
	elif dx > 0.0:
		_facing = 1
	return _facing


func _fire() -> void:
	if target == null or not is_instance_valid(target):
		return
	var parent := bullet_parent if bullet_parent != null else get_parent()
	if parent == null:
		return
	var b := Bullet.new()
	parent.add_child(b)
	var from := global_position + Vector2(0.0, -Feel.ENEMY_SIZE.y * 0.25)
	var aim := (target.global_position - from).normalized()
	b.launch(from, aim, Feel.ENEMY_BULLET_SPEED, Feel.ENEMY_BULLET_DAMAGE, false, 0)


func _die() -> void:
	Feel.spawn_explosion(get_parent(), global_position, Feel.ENEMY_SIZE * Feel.EXPLOSION_SCALE)
	died.emit(points)
	queue_free()
