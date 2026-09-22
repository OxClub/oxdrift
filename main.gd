extends Node3D

const SPAWN := Vector3(0, 0.7, 22)
const SPAWN_YAW := -PI / 2.0
const RX := 30.0
const RZ := 22.0

var car: DriftCar
var cam: Camera3D
var steer := 0.0
var gas := 0.0
var braking := 0.0
var nitro := false

var score := 0.0
var run_time := 0.0
var lap_time := 0.0
var best_lap := 0.0
var halfway := false

var lbl_speed: Label
var lbl_lap: Label
var lbl_best: Label
var lbl_score: Label
var lbl_drift: Label
var bar_nitro: ProgressBar

func _ready() -> void:
    cam = get_node("Cam") as Camera3D
    build_environment()
    build_track()
    spawn_car()
    build_ui()
    load_best()

func build_environment() -> void:
    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.09, 0.04, 0.2)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.7, 0.7, 0.9)
    env.ambient_light_energy = 0.9
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
    sun.light_energy = 1.2
    add_child(sun)

func add_box(pos: Vector3, size: Vector3, color: Color, solid: bool, yaw := 0.0) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mi.material_override = mat
    mi.position = pos
    mi.rotation.y = yaw
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        body.rotation.y = yaw
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        body.add_child(col)
        body.add_child(mi)
        add_child(body)
    else:
        add_child(mi)

func build_track() -> void:
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(220, 220)
    ground.mesh = pm
    var gmat := StandardMaterial3D.new()
    gmat.albedo_color = Color(0.13, 0.1, 0.25)
    ground.material_override = gmat
    add_child(ground)
    var gbody := StaticBody3D.new()
    var gcol := CollisionShape3D.new()
    var gshape := WorldBoundaryShape3D.new()
    gcol.shape = gshape
    gbody.add_child(gcol)
    add_child(gbody)

    var segs := 64
    var prev := Vector3(RX * sin(0.0), 0, RZ * cos(0.0))
    for i in range(1, segs + 1):
        var t := TAU * i / segs
        var cur := Vector3(RX * sin(t), 0, RZ * cos(t))
        var mid := (prev + cur) * 0.5
        var seg_len := prev.distance_to(cur)
        var yaw := atan2(cur.x - prev.x, cur.z - prev.z)
        add_box(mid + Vector3(0, 0.03, 0), Vector3(8, 0.06, seg_len + 0.5),
            Color(0.2, 0.2, 0.24), false, yaw)
        for side in [-4.0, 4.0]:
            var off := Vector3(sin(yaw + PI / 2), 0, cos(yaw + PI / 2)) * side
            add_box(mid + off + Vector3(0, 0.35, 0), Vector3(0.4, 0.7, seg_len + 0.3),
                Color(0.85, 0.85, 0.9) if i % 2 == 0 else Color(0.9, 0.25, 0.5), true, yaw)
        prev = cur

    add_box(Vector3(0, 0.08, 22), Vector3(1.6, 0.02, 8), Color.WHITE, false)

    var rng := RandomNumberGenerator.new()
    rng.seed = 20250921
    for i in range(26):
        var ang := TAU * i / 26.0
        var r := rng.randf_range(40, 50)
        var h := rng.randf_range(6, 20)
        var col := Color.from_hsv(rng.randf_range(0.6, 0.95), 0.7, 0.8)
        add_box(Vector3(cos(ang) * r, h / 2.0, sin(ang) * r),
            Vector3(rng.randf_range(4, 8), h, rng.randf_range(4, 8)), col, true)

func spawn_car() -> void:
    car = DriftCar.new()
    add_child(car)
    car.reset_to(SPAWN, SPAWN_YAW)
    car.drift_scored.connect(_on_drift)

func build_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)

    lbl_speed = make_label(ui, Vector2(20, 16), 52)
    lbl_lap = make_label(ui, Vector2(440, 16), 30)
    lbl_best = make_label(ui, Vector2(440, 62), 24)
    lbl_score = make_label(ui, Vector2(880, 16), 30)
    lbl_drift = make_label(ui, Vector2(540, 300), 46)
    lbl_drift.modulate = Color(1, 0.3, 0.75)

    bar_nitro = ProgressBar.new()
    bar_nitro.min_value = 0
    bar_nitro.max_value = 100
    bar_nitro.value = 100
    bar_nitro.position = Vector2(460, 110)
    bar_nitro.size = Vector2(360, 16)
    ui.add_child(bar_nitro)

    var reset := make_button(ui, "RESET", Vector2(1150, 80), Color(0.9, 0.3, 0.3))
    reset.pressed.connect(func(): car.reset_to(SPAWN, SPAWN_YAW))

    var b_left := make_button(ui, "<", Vector2(30, 520), Color(0.2, 0.3, 0.6))
    var b_right := make_button(ui, ">", Vector2(200, 520), Color(0.2, 0.3, 0.6))
    var b_gas := make_button(ui, "GAS", Vector2(1100, 520), Color(0.1, 0.6, 0.3))
    var b_brake := make_button(ui, "BRAKE", Vector2(1100, 370), Color(0.7, 0.25, 0.2))
    var b_nitro := make_button(ui, "NITRO", Vector2(920, 520), Color(0.9, 0.6, 0.1))

    hold(b_left, "left")
    hold(b_right, "right")
    hold(b_gas, "gas")
    hold(b_brake, "brake")
    hold(b_nitro, "nitro")

func hold(b: Button, which: String) -> void:
    b.button_down.connect(func(): _set_flag(which, true))
    b.button_up.connect(func(): _set_flag(which, false))

func _set_flag(which: String, v: bool) -> void:
    match which:
        "left": steer = -1.0 if v else 0.0
        "right": steer = 1.0 if v else 0.0
        "gas": gas = 1.0 if v else 0.0
        "brake": braking = 1.0 if v else 0.0
        "nitro": nitro = v

func make_label(ui: CanvasLayer, pos: Vector2, fsize: int) -> Label:
    var l := Label.new()
    l.position = pos
    l.add_theme_font_size_override("font_size", fsize)
    l.add_theme_color_override("font_color", Color.WHITE)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    l.add_theme_constant_override("outline_size", 8)
    ui.add_child(l)
    return l

func make_button(ui: CanvasLayer, txt: String, pos: Vector2, color: Color) -> Button:
    var b := Button.new()
    b.text = txt
    b.position = pos
    b.size = Vector2(150, 150)
    b.add_theme_font_size_override("font_size", 34)
    b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(color.r, color.g, color.b, 0.85)
    sb.corner_radius_top_left = 24
    sb.corner_radius_top_right = 24
    sb.corner_radius_bottom_left = 24
    sb.corner_radius_bottom_right = 24
    b.add_theme_stylebox_override("normal", sb)
    ui.add_child(b)
    return b

func _on_drift(points: float) -> void:
    score += points
    lbl_drift.text = "DRIFT! +%d" % int(points * 60)

func _process(delta: float) -> void:
    car.steer_input = steer
    if Input.is_physical_key_pressed(KEY_LEFT): car.steer_input = -1.0
    elif Input.is_physical_key_pressed(KEY_RIGHT): car.steer_input = 1.0

    car.throttle = gas
    if Input.is_physical_key_pressed(KEY_UP): car.throttle = 1.0

    car.brake_input = braking
    if Input.is_physical_key_pressed(KEY_DOWN): car.brake_input = 1.0

    car.nitro_held = nitro or Input.is_physical_key_pressed(KEY_SPACE)

    run_time += delta
    lap_time += delta
    var p := car.global_position
    if p.z < -10: halfway = true
    if halfway and Vector2(p.x, p.z).distance_to(Vector2(0, 22)) < 5 and lap_time > 12:
        if best_lap == 0 or lap_time < best_lap:
            best_lap = lap_time
            save_best()
        lap_time = 0
        halfway = false

    lbl_speed.text = "%d km/h" % int(absf(car.forward_speed) * 3.6)
    lbl_lap.text = "Lap: %.1fs" % lap_time
    lbl_best.text = "Best: %s" % ("%.1fs" % best_lap if best_lap > 0 else "--")
    lbl_score.text = "Cash %d" % int(score)
    bar_nitro.value = car.nitro_fuel
    if not car.drifting:
        lbl_drift.text = ""

    var dir := -car.global_transform.basis.z
    var target_pos := car.global_position - dir * 7.0 + Vector3(0, 3.2, 0)
    cam.position = cam.position.lerp(target_pos, 5.0 * delta)
    cam.look_at(car.global_position + dir * 3.0 + Vector3(0, 1, 0))

    if Input.is_physical_key_pressed(KEY_R):
        car.reset_to(SPAWN, SPAWN_YAW)

func load_best() -> void:
    var cf := ConfigFile.new()
    if cf.load("user://oxdrift.cfg") == OK:
        best_lap = cf.get_value("stats", "best_lap", 0.0)
        score = cf.get_value("stats", "total_score", 0.0)

func save_best() -> void:
    var cf := ConfigFile.new()
    cf.set_value("stats", "best_lap", best_lap)
    cf.set_value("stats", "total_score", score)
    cf.save("user://oxdrift.cfg")
