class_name DriftCar
extends VehicleBody3D

signal drift_scored(points: float)
signal nitro_changed(fuel: float)

const MAX_STEER := 0.55
const ENGINE := 2600.0
const NITRO_ENGINE := 4400.0
const BRAKE := 55.0

var steer_input := 0.0
var throttle := 0.0
var brake_input := 0.0
var nitro_held := false
var nitro_fuel := 100.0
var forward_speed := 0.0
var drifting := false

func _ready() -> void:
    mass = 900.0
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0, -0.4, 0)

    var col := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.9, 0.8, 4.0)
    col.shape = box
    col.position = Vector3(0, 0.55, 0)
    add_child(col)

    add_body_mesh(Vector3(0, 0.55, 0), Vector3(1.9, 0.55, 4.0), Color(1.0, 0.18, 0.66))
    add_body_mesh(Vector3(0, 1.0, -0.3), Vector3(1.5, 0.45, 1.8), Color(0.1, 0.12, 0.25))
    add_body_mesh(Vector3(0, 1.0, 1.7), Vector3(1.7, 0.12, 0.5), Color(0.1, 0.12, 0.25))

    var wheel_scene := CylinderMesh.new()
    wheel_scene.top_radius = 0.35
    wheel_scene.bottom_radius = 0.35
    wheel_scene.height = 0.3
    wheel_scene.radial_segments = 16

    for pos in [Vector3(-0.95, 0.1, -1.45), Vector3(0.95, 0.1, -1.45),
            Vector3(-0.95, 0.1, 1.45), Vector3(0.95, 0.1, 1.45)]:
        var w := VehicleWheel3D.new()
        w.position = pos
        w.wheel_radius = 0.35
        w.wheel_rest_length = 0.25
        w.suspension_travel = 0.25
        w.suspension_stiffness = 45.0
        w.suspension_max_force = 9000.0
        w.damping_compression = 4.0
        w.damping_relaxation = 4.5
        w.wheel_friction_slip = 3.0 if pos.z < 0 else 2.6
        w.wheel_roll_influence = 0.08
        w.use_as_steering = pos.z < 0
        w.use_as_traction = pos.z > 0

        var mi := MeshInstance3D.new()
        mi.mesh = wheel_scene
        mi.rotation = Vector3(0, 0, deg_to_rad(90))
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.08, 0.08, 0.1)
        mi.material_override = mat
        w.add_child(mi)
        add_child(w)

func add_body_mesh(pos: Vector3, size: Vector3, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mi.material_override = mat
    add_child(mi)

func _physics_process(delta: float) -> void:
    var lv := global_transform.basis.inverse() * linear_velocity
    forward_speed = -lv.z

    var target := steer_input * MAX_STEER
    steering = move_toward(steering, target, delta * 2.8)

    var force := 0.0
    var braking := 0.0

    if brake_input > 0 and forward_speed < 0.5:
        force = -1300.0
    elif throttle > 0 and forward_speed < (55.0 if nitro_held else 42.0):
        force = (NITRO_ENGINE if nitro_held else ENGINE) * throttle
    elif brake_input > 0:
        braking = BRAKE * brake_input

    engine_force = force
    brake = braking

    if nitro_held and throttle > 0 and nitro_fuel > 0 and forward_speed > 1:
        nitro_fuel = maxf(nitro_fuel - 30.0 * delta, 0)
        nitro_changed.emit(nitro_fuel)
    else:
        nitro_fuel = minf(nitro_fuel + 8.0 * delta, 100)
        nitro_changed.emit(nitro_fuel)

    drifting = false
    if forward_speed > 9 and absf(lv.x) > 3.5:
        drifting = true
        drift_scored.emit(absf(lv.x) * delta * 15.0)

func reset_to(pos: Vector3, yaw: float) -> void:
    global_position = pos
    rotation = Vector3(0, yaw, 0)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    steering = 0
