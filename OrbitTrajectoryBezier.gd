@tool
class_name OrbitTrajectoryBezier extends Path3D

signal trajectory_param_changed

#---------------------------------------------------------------------------------------------------
# PUBLIC VARIABLES
#---------------------------------------------------------------------------------------------------
@export_category("Orbital Parameters")

@export var angular_momentum: float = 1.0 :
	set(new_value):
		angular_momentum = new_value
		trajectory_param_changed.emit()
		
@export var perihelion: float = 1.0:
	set(new_value):
		perihelion = new_value
		trajectory_param_changed.emit()
		
@export var standard_gravitational_param: float = 1.0:
	set(new_value):
		standard_gravitational_param = new_value
		trajectory_param_changed.emit()

## If 'true' the generated mesh ends with an hemispherical surface
@export var trajectory_clip_radius: float = 4000.0:
	set(value):
		trajectory_clip_radius = value
		trajectory_param_changed.emit()

# Called when the node enters the scene tree for the first time.
func _ready():
	trajectory_param_changed.connect(_on_trajectory_changed)
	trajectory_param_changed.emit()

func _on_trajectory_changed():
	self.curve.clear_points()
	self.curve = self._reconstruct_trajectory_cartesian(\
	angular_momentum,\
	perihelion,\
	standard_gravitational_param )

# Function to reconstruct trajectory in Cartesian coordinates
func _reconstruct_trajectory_cartesian(h, q, mu):
	var new_curve = Curve3D.new()
	# Calculate eccentricity
	var e : float = (h * h) / (mu * q) - 1.0
	var a = q / (1.0 - e)

	# Determine the type of trajectory
	var trajectory_type = ""
	if e - 1 < -1e-10:
		trajectory_type = "elliptic"
	elif e - 1 > 1e-10:
		trajectory_type = "hyperbolic"
	else:
		trajectory_type = "parabolic"

	# Define a range of true anomalies
	var theta_max = PI
	match trajectory_type:
		"elliptic":
			const EtoBconst = 4.0/3.0 * (sqrt(2) - 1)
			var b = a * sqrt(1 - e**2)
			var fShift = Vector3(q,0.0,0.0)-Vector3(a,0.0,0.0)
			new_curve.add_point(\
			Vector3(a,0.0,0.0) + fShift,\
			Vector3(0.0,-EtoBconst*b,0.0),\
			Vector3(0.0, EtoBconst*b,0.0))
			new_curve.add_point(\
			Vector3(0.0,b,0.0) + fShift,\
			Vector3(EtoBconst*a,0.0,0.0),\
			Vector3(-EtoBconst*a,0.0,0.0))
			new_curve.add_point(\
			Vector3(-a,0.0,0.0) + fShift,\
			Vector3(0.0,EtoBconst*b,0.0),\
			Vector3(0.0,-EtoBconst*b,0.0))
			new_curve.add_point(\
			Vector3(0.0,-b,0.0) + fShift,\
			Vector3(-EtoBconst*a,0.0,0.0),\
			Vector3(EtoBconst*a,0.0,0.0))
			new_curve.add_point(\
			Vector3(a,0.0,0.0) + fShift,\
			Vector3(0.0,-EtoBconst*b,0.0),\
			Vector3(0.0, EtoBconst*b,0.0))
			theta_max = PI

		"hyperbolic":
			var b = a * sqrt(e**2 - 1)
			var foci = Vector3(-a*e,0.0,0.0)
			new_curve.add_point(\
			Vector3(2 * a, b * sqrt(3),0.0) + foci,\
			-Vector3(2.0/3.0 * a, b * (48-26 * sqrt(3.0) )/18.0,0.0)-Vector3(2 * a, b * sqrt(3),0.0),\
			Vector3(2.0/3.0 * a, b * (48-26 * sqrt(3.0) )/18.0,0.0)-Vector3(2 * a, b * sqrt(3),0.0))
			new_curve.add_point(\
			Vector3(2 *a, -b * sqrt(3),0.0) + foci,\
			Vector3(2.0/3.0 * a, -b * (48-26 * sqrt(3.0) )/18.0,0.0)-Vector3(2 *a, -b * sqrt(3),0.0),\
			-Vector3(2.0/3.0 * a, b * (48-26 * sqrt(3.0) )/18.0,0.0)-Vector3(2 *a, -b * sqrt(3),0.0))
			theta_max = acos(-1.0 / e)
			
		"parabolic":
			var theta0 = PI*0.9
			var r = (h * h / mu) / (1.0 + e * cos(theta0))
			var x_min = r*sin(-theta0)
			var y_min = r*cos(-theta0)-q
			var x_max = r*sin(theta0)
			var y_max = r*cos(theta0)-q
			var p_a = y_min/(x_min**2.0)
			var cy = (x_max-x_min)*p_a*x_min + y_min
			var cx = (x_min+x_max)/2.0
			var p1 = -2.0/3.0*Vector3(y_min, x_min,0.0) +2.0/3.0*Vector3(cy,cx,0)
			var p2 = -2.0/3.0*Vector3(y_max, x_max,0.0) +2.0/3.0*Vector3(cy,cx,0)
			var foci = Vector3(q,0.0,0.0)
			new_curve.add_point(\
			Vector3(y_min, x_min,0.0) + foci,-p1,p1)
			new_curve.add_point(\
			Vector3(y_max, x_max,0.0) + foci,p2,-p2)
			theta_max = PI

		_:
			push_error("Invalid trajectory type")

	return new_curve
