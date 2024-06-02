extends CharacterBody3D

const SPEED: float = 4.0
const JUMP_VELOCITY: float = 4.5
const FALL_DOWN_MULT: float = JUMP_VELOCITY / 2
const SLIPPERINESS: float = 0.8
const SENSITIVITY: int = 30
const PITCH_CLAMP: int = 80
const BOB_FREQ: float = 0.8
const BOB_AMPL: float = 0.3
const BOB_SMOOTHNESS: float = 16.0
const SPRINT_MULT: float = 2.0
const CROUCH_HEIGHT: float = 1.0
const CROUCH_SPEED: float = 2.4
const CROUCH_MULT: float = 0.5
const CROUCH_POS: float = -0.5

var sens_factor: float = 0.0001
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var bobbing_timer: float = 0.0
var cam_lerp_fac: float = 2.0
var sprinting: bool = false
var crouching: bool = false
var crouch_height_orig: float

@onready var orient = $Orientation
@onready var cam = $Orientation/Head/Camera3D
@onready var head = $Orientation/Head
@onready var col = $CollisionShape3D
@onready var ceiling_chk = $CeilingCheck

func handle_crouch(delta):
	head.position.y = move_toward(head.position.y, 0.0 if not crouching else CROUCH_POS, delta*CROUCH_SPEED)
	
	col.shape.height = crouch_height_orig if not crouching else CROUCH_HEIGHT
	col.position.y = 0.0 if not crouching else CROUCH_POS
	
	if crouching:
		sprinting = false

func _input(event):
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		orient.rotate_y(-event.relative.x * SENSITIVITY * sens_factor)
		cam.rotate_x(-event.relative.y * SENSITIVITY * sens_factor)
		cam.rotation_degrees.x = clamp(cam.rotation_degrees.x, -PITCH_CLAMP, PITCH_CLAMP)

func _ready():
	crouch_height_orig = col.shape.height

func _physics_process(delta):
	handle_crouch(delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta * (FALL_DOWN_MULT if velocity.y <= 0.0 else 1.0)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("sprint") and not crouching:
		sprinting = true
	if Input.is_action_just_released("sprint"):
		sprinting = false
		
	if Input.is_action_just_pressed("crouch"):
		if not crouching:
			crouching = true
		elif not ceiling_chk.is_colliding():
			crouching = false

	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (orient.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var move_speed = SPEED * (SPRINT_MULT if sprinting else 1.0) * (CROUCH_MULT if crouching else 1.0)
	var slipperiness_delta = SPEED*SLIPPERINESS*delta
	if direction:
		velocity.x = lerp(velocity.x, direction.x * move_speed, slipperiness_delta)
		velocity.z = lerp(velocity.z, direction.z * move_speed, slipperiness_delta)
		
		if is_on_floor():
			cam.position.y = lerp(cam.position.y, abs(sin(bobbing_timer * BOB_FREQ * move_speed) * BOB_AMPL), delta*BOB_SMOOTHNESS)
			cam.position.x = lerp(cam.position.x, sin(bobbing_timer * BOB_FREQ * move_speed) * BOB_AMPL, delta*BOB_SMOOTHNESS)
			bobbing_timer += delta
	else:
		velocity.x = lerp(velocity.x, 0.0, slipperiness_delta)
		velocity.z = lerp(velocity.z, 0.0, slipperiness_delta)
		
	if not direction or not is_on_floor():
		bobbing_timer = 0.0
		cam.position = lerp(cam.position, Vector3.ZERO, delta*cam_lerp_fac)

	move_and_slide()
