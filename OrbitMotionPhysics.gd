@tool
class_name OrbitMotionPhysics extends Node3D

var rd : OrbitTrajectoryRenderer
var debug_mesh : MeshInstance3D

enum INITIALIZE_METHOD {DEFAULT, RANDOM, ZERO = -1}

@export_category("Misc")
@export var attach_point : Node3D
@export_range(-1,1,1) var simulation_speed : float = 0.0
@export \
var initialize_method: INITIALIZE_METHOD = INITIALIZE_METHOD.DEFAULT
@export var enable_debug_ball : bool = true

@export_category("Physical Parameters")
@export var pos : Vector3
@export var vel : Vector3
@export var acc : Vector3

@export_category("Orbital Parameters")
@export var trajectoryType = ""
@export var r : float :
	get:
		return pos.length()
@export var theta : float
@export var t : float
@export var e_axis : Vector3 :
	get:
		return (((vel.length_squared()\
		 - rd.standard_gravitational_param/pos.length())\
		 * pos - pos.dot(vel) * vel) \
		/ rd.standard_gravitational_param).normalized()
	set(_val):
		pass
@export var h_axis : Vector3 :
	get:
		return pos.cross(vel).normalized()
	set(_val):
		pass

func _initialize_body():
	acc = _apply_forces()
	_update_orbit_params()

func _update_orbit_params():
	# Do not update orbit parameters 
	# when no velocity or position available
	if vel.length_squared() < 1e-10\
	|| pos.length_squared() < 1e-10:
		return
		
	# Do not update orbit parameters
	# when degenerates to radial trajectory
	if (1.0 - pos.normalized().dot(vel.normalized())) < 1e-6:
		return

	# Create a new Basis from these vectors
	rd.transform = Basis(e_axis, -h_axis.cross(e_axis), h_axis)
	var orbit_params = orbitParameters(pos, vel, rd.standard_gravitational_param)
	if abs(rd.angular_momentum - orbit_params[2]) > 1e-3 * rd.angular_momentum:
		rd.angular_momentum = orbit_params[2]
	if abs(rd.perihelion - orbit_params[3]) > 1e-3 * rd.perihelion:
		rd.perihelion = orbit_params[3]
	theta = orbit_params[0]
	t = orbit_params[1]

# Called when the node enters the scene tree for the first time.
func _ready():
	_initialize_body()
	if enable_debug_ball:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.mesh = SphereMesh.new()
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(\
		 randf_range(0.1, 1.0)\
		,randf_range(0.1, 1.0)\
		,randf_range(0.1, 1.0))
		debug_mesh.mesh.material = material
		debug_mesh.tree_entered.connect(\
		debug_mesh.set_owner.bind(self))
		add_child(debug_mesh)
		attach_point = debug_mesh
		

func _physics_process(delta):
	vel = vel + acc * (delta * 0.5) * simulation_speed
	pos = pos + vel * delta * simulation_speed
	acc = _apply_forces()
	vel = vel + acc * (delta * 0.5) * simulation_speed
	
	if attach_point:
		attach_point.position = pos
		
	call_deferred("_update_orbit_params")

func _apply_forces():
	var new_acc = rd.standard_gravitational_param / r**3 *(-pos) # Gravity acceleration
	return Vector3.ZERO if is_nan(new_acc.length()) else new_acc
	
func _enter_tree():
	rd = OrbitTrajectoryRenderer.new()
	rd.tree_entered.connect(rd.set_owner.bind(self))
	add_child(rd)
	
func _exit_tree():
	if rd:
		rd.queue_free()
	if debug_mesh:
		debug_mesh.queue_free()

# GDScript version of the orbitParameters function
func orbitParameters(r, v, mu):
	# Calculate Angular Momentum
	var h_vec = r.cross(v)
	var h = h_vec.length()

	# Calculate eccentricity vector
	var e_vec = ((v.length_squared() - mu/r.length()) * r - r.dot(v) * v) / mu
	var e = e_vec.length()

	# Calculate true anomaly
	var u = e_vec.cross(r)
	var w = -u
	if u.cross(Vector3(0,0,1)).length_squared() >= 0:
		w = u
	var q = w.cross(e_vec)

	if abs(e) < 1e-10:
		theta = atan2(r.y, r.x)
	else:
		theta = acos(e_vec.normalized().dot(r.normalized()))
		if r.dot(q) < 0:
			theta = -theta

	# Calculate specific orbital energy
	var epsilon = v.length_squared() / 2 - mu / r.length()

	# Determine the type of trajectory
	if epsilon < -1e-10:
		trajectoryType = "elliptic"
	elif epsilon > 1e-10:
		trajectoryType = "hyperbolic"
	else:
		trajectoryType = "parabolic"

	# Compute perihelion distance q and other parameters
	match trajectoryType:
		"elliptic":
			q = (h * h / mu) / (1 + e)
			var a = -mu / (2 * epsilon)
			var n = sqrt(mu / a**3)
			var E_anomaly = 2 * atan2(sqrt((1-e)/(1+e)) * sin(theta/2), cos(theta/2))
			t = (E_anomaly - e * sin(E_anomaly)) / n

		"hyperbolic":
			q = (h * h / mu) / (1 + e)
			var a = mu / (2 * epsilon)
			var n = sqrt(mu / a**3)
			var F_anomaly = 2 * atanh(sqrt((e-1)/(e+1)) * tan(theta/2))
			t = (e * sinh(F_anomaly) - F_anomaly) / n
			
		"parabolic":
			q = h * h / (2 * mu)
			var D = tan(theta / 2)
			t = (D**3 / 3 + D) * sqrt(2 * q**3 / mu)

		_:
			print("Invalid trajectory type")

	return [theta, t, h, q]

func atanh(x: float) -> float:
	if abs(x) >= 1:
		return 0

	return 0.5 * log((1 + x) / (1 - x))
