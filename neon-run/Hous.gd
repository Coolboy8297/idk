
@tool
extends EditorScript

const W := 48.0
const D := 36.0
const H := 5.0
const T := 0.5
const LEVELS := 3
const WW := 3.0
const WB := 1.5
const WT := 3.7

var scene_root: Node
var house: Node3D
var wall: Material
var floor_mat: Material
var roof_mat: Material
var glass: StandardMaterial3D
var frame: Material
var wood: Material
var trim: Material


func _run() -> void:
	scene_root = get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		push_error("Open a 3D scene first.")
		return

	var old = scene_root.get_node_or_null("GiantHouse")
	if old:
		old.free()

	house = Node3D.new()
	house.name = "GiantHouse"
	scene_root.add_child(house)
	house.owner = scene_root

	wall = mat(Color(0.72, 0.69, 0.63))
	floor_mat = mat(Color(0.32, 0.24, 0.17))
	roof_mat = mat(Color(0.13, 0.15, 0.19))
	frame = mat(Color(0.12, 0.10, 0.09))
	wood = mat(Color(0.35, 0.20, 0.12))
	trim = mat(Color(0.83, 0.77, 0.64))

	glass = mat(Color(0.35, 0.72, 0.95, 0.28))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	for level in range(LEVELS):
		var y := float(level) * H

		# Original giant floors
		box("Floor", Vector3(0, y - 0.25, 0),
			Vector3(W, 0.5, D), floor_mat)

		# ACTUAL WINDOW OPENINGS IN ALL FOUR OUTER WALLS
		window_wall_x(-D / 2, y, W)
		window_wall_x(D / 2, y, W)
		window_wall_z(-W / 2, y, D)
		window_wall_z(W / 2, y, D)

		# Interior rooms with actual door openings
		doorway_x(-7, y, 30, 0)
		doorway_z(-10, y, 15, 5)

		# Original support columns
		for x in [-18.0, 18.0]:
			for z in [-12.0, 12.0]:
				box("SupportColumn",
					Vector3(x, y + H / 2, z),
					Vector3(0.7, H, 0.7), trim)

		# Original staircase
		for i in range(18):
			var height := float(i + 1) * H / 18.0
			box("Stair",
				Vector3(17, y + height / 2,
					-10 + float(i) * 0.65),
				Vector3(4, height, 0.72), wood)

	# Original roof and front porch
	box("Roof", Vector3(0, LEVELS * H, 0),
		Vector3(W + 2, 0.8, D + 2), roof_mat)

	box("RoofTrim", Vector3(0, 14.9, -D / 2 - 0.5),
		Vector3(W + 2, 0.6, 0.5), wood)

	box("EntrancePorch", Vector3(0, -0.15, -D / 2 - 3),
		Vector3(12, 0.4, 6), trim)

	for x in [-5.0, 5.0]:
		box("PorchPillar",
			Vector3(x, 2, -D / 2 - 5),
			Vector3(0.5, 4, 0.5), trim)

	# Playable first-person character
	make_player()

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.2
	house.add_child(sun)
	own(sun)

	get_editor_interface().mark_scene_as_unsaved()
	print("Original giant house generated with real windows and player.")


# --------------------------------------------------
# REAL WINDOWS: WALL SECTIONS STOP AT EACH OPENING
# --------------------------------------------------

func window_wall_x(z: float, y: float, length: float) -> void:
	var centers: Array[float] = []
	for i in range(int(length / 7.0)):
		centers.append(-length / 2 + 4 + i * 7)

	var cursor := -length / 2

	for center in centers:
		var left := center - WW / 2
		var right := center + WW / 2

		if left > cursor:
			box("WallPier",
				Vector3((cursor + left) / 2, y + H / 2, z),
				Vector3(left - cursor, H, T), wall)

		box("WindowSill",
			Vector3(center, y + WB / 2, z),
			Vector3(WW, WB, T), wall)

		box("WindowHeader",
			Vector3(center, y + (WT + H) / 2, z),
			Vector3(WW, H - WT, T), wall)

		window_frame_x(center, y, z)
		cursor = right

	if cursor < length / 2:
		box("WallPier",
			Vector3((cursor + length / 2) / 2, y + H / 2, z),
			Vector3(length / 2 - cursor, H, T), wall)


func window_wall_z(x: float, y: float, length: float) -> void:
	var centers: Array[float] = []
	for i in range(int(length / 7.0)):
		centers.append(-length / 2 + 4 + i * 7)

	var cursor := -length / 2

	for center in centers:
		var left := center - WW / 2
		var right := center + WW / 2

		if left > cursor:
			box("WallPier",
				Vector3(x, y + H / 2, (cursor + left) / 2),
				Vector3(T, H, left - cursor), wall)

		box("WindowSill",
			Vector3(x, y + WB / 2, center),
			Vector3(T, WB, WW), wall)

		box("WindowHeader",
			Vector3(x, y + (WT + H) / 2, center),
			Vector3(T, H - WT, WW), wall)

		window_frame_z(x, y, center)
		cursor = right

	if cursor < length / 2:
		box("WallPier",
			Vector3(x, y + H / 2, (cursor + length / 2) / 2),
			Vector3(T, H, length / 2 - cursor), wall)


func window_frame_x(x: float, y: float, z: float) -> void:
	var center_y := y + (WB + WT) / 2
	var height := WT - WB

	# Glass has no collision, and you can see through it.
	visual_box("TransparentGlass",
		Vector3(x, center_y, z),
		Vector3(WW - 0.12, height - 0.12, 0.06), glass)

	for side in [-1.0, 1.0]:
		box("WindowFrame",
			Vector3(x + side * (WW / 2 - 0.06), center_y, z),
			Vector3(0.12, height, 0.14), frame)

	box("WindowFrame",
		Vector3(x, y + WB, z),
		Vector3(WW, 0.12, 0.14), frame)

	box("WindowFrame",
		Vector3(x, y + WT, z),
		Vector3(WW, 0.12, 0.14), frame)


func window_frame_z(x: float, y: float, z: float) -> void:
	var center_y := y + (WB + WT) / 2
	var height := WT - WB

	visual_box("TransparentGlass",
		Vector3(x, center_y, z),
		Vector3(0.06, height - 0.12, WW - 0.12), glass)

	for side in [-1.0, 1.0]:
		box("WindowFrame",
			Vector3(x, center_y, z + side * (WW / 2 - 0.06)),
			Vector3(0.14, height, 0.12), frame)

	box("WindowFrame",
		Vector3(x, y + WB, z),
		Vector3(0.14, 0.12, WW), frame)

	box("WindowFrame",
		Vector3(x, y + WT, z),
		Vector3(0.14, 0.12, WW), frame)


# --------------------------------------------------
# INTERIOR DOORS: OPENINGS THROUGH DIVIDER WALLS
# --------------------------------------------------

func doorway_x(z: float, y: float,
		length: float, center: float) -> void:
	var dw := 2.0
	var dh := 3.0
	var left := center - dw / 2
	var right := center + dw / 2

	box("InteriorWall", Vector3((-length / 2 + left) / 2,
		y + H / 2, z),
		Vector3(left + length / 2, H, T), wall)

	box("InteriorWall", Vector3((right + length / 2) / 2,
		y + H / 2, z),
		Vector3(length / 2 - right, H, T), wall)

	box("DoorHeader", Vector3(center, y + dh + (H - dh) / 2, z),
		Vector3(dw, H - dh, T), wall)


func doorway_z(x: float, y: float,
		length: float, center: float) -> void:
	var dw := 2.0
	var dh := 3.0
	var left := center - dw / 2
	var right := center + dw / 2

	box("InteriorWall", Vector3(x, y + H / 2,
		(-length / 2 + left) / 2),
		Vector3(T, H, left + length / 2), wall)

	box("InteriorWall", Vector3(x, y + H / 2,
		(right + length / 2) / 2),
		Vector3(T, H, length / 2 - right), wall)

	box("DoorHeader", Vector3(x, y + dh + (H - dh) / 2, center),
		Vector3(T, H - dh, dw), wall)


# --------------------------------------------------
# REAL FIRST-PERSON CHARACTER
# --------------------------------------------------

func make_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 12)
	house.add_child(player)
	own(player)

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	own(collider)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.6
	camera.fov = 85
	player.add_child(camera)
	own(camera)

	var controller := GDScript.new()
	controller.source_code = """
extends CharacterBody3D

@export var walk_speed := 6.0
@export var sprint_speed := 11.0
@export var jump_force := 8.0
@export var mouse_sensitivity := 0.002

var gravity := 24.0
@onready var cam: Camera3D = $Camera3D

func _ready() -> void:
    cam.current = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    if event is InputEventMouseButton and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    if event is InputEventMouseMotion:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            rotate_y(-event.relative.x * mouse_sensitivity)
            cam.rotate_x(-event.relative.y * mouse_sensitivity)
            cam.rotation.x = clamp(cam.rotation.x, -1.5, 1.5)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

    if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = jump_force

    var input_dir := Vector2.ZERO
    if Input.is_key_pressed(KEY_A):
        input_dir.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        input_dir.x += 1.0
    if Input.is_key_pressed(KEY_W):
        input_dir.y -= 1.0
    if Input.is_key_pressed(KEY_S):
        input_dir.y += 1.0

    input_dir = input_dir.normalized()
    var direction := (transform.basis * Vector3(
        input_dir.x, 0, input_dir.y
    )).normalized()

    var current_speed := walk_speed
    if Input.is_key_pressed(KEY_SHIFT):
        current_speed = sprint_speed

    velocity.x = direction.x * current_speed
    velocity.z = direction.z * current_speed
    move_and_slide()
"""
	controller.resource_name = "PlayerController"
	player.set_script(controller)


# --------------------------------------------------
# EDITOR-SAFE BUILD HELPERS
# --------------------------------------------------

func own(node: Node) -> void:
	node.owner = scene_root


func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func box(label: String, pos: Vector3, size: Vector3,
		material: Material, solid: bool = true) -> void:
	var obj: Node3D
	if solid:
		obj = StaticBody3D.new()
	else:
		obj = Node3D.new()

	obj.name = label
	obj.position = pos
	house.add_child(obj)
	own(obj)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = material
	obj.add_child(mesh)
	own(mesh)

	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		obj.add_child(collision)
		own(collision)


func visual_box(label: String, pos: Vector3,
		size: Vector3, material: Material) -> void:
	box(label, pos, size, material, false)
