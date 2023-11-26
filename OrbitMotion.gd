@tool
class_name OrbitMotion extends Node3D

@onready var rd : OrbitTrajectoryRenderer = $OrbitTrajectoryRenderer
@onready var anim_player : AnimationPlayer = $AnimationPlayer

@export_category("Misc")
@export var attach_point : Node3D
@export_range(10, 400, 10) var num_segments : int = 50

@export_category("Physical Parameters")
@export var pos : Vector3
@export var vel : Vector3
@export var acc : Vector3
@export var e_axis : Vector3 = Vector3.UP :
	get:
		return transform.basis.x.normalized()
@export var h_axis : Vector3 = Vector3.BACK :
	get:
		return transform.basis.z.normalized()
@export var t_max : float

@export_category("Orbital Parameters")
@export var trajectory_type = ""
@export var r : float
@export var theta : float
@export var angular_momentum: float = 1.0 :
	set(new_value):
		angular_momentum = new_value
		rd.angular_momentum = angular_momentum
		
@export var perihelion: float = 1.0:
	set(new_value):
		perihelion = new_value
		rd.perihelion = perihelion
		
@export var standard_gravitational_param: float = 1.0:
	set(new_value):
		standard_gravitational_param = new_value
		rd.standard_gravitational_param = new_value

# Called when the node enters the scene tree for the first time.
func _ready():
	rd.trajectory_param_changed.connect(self.update_orbit_motion)
	rd.trajectory_param_changed.emit()
	
func update_orbit_motion():
	anim_player.stop()
	
	# Check if an animation with the same name already exists
	var anim_lib
	var animlib_name = "orbit_anim"
	if anim_player.has_animation_library(animlib_name):
		anim_lib = anim_player.get_animation_library(animlib_name)
	else:
		anim_lib = AnimationLibrary.new()
		anim_player.add_animation_library(animlib_name, anim_lib)
	
	var anim_name = "orbit"
	if anim_player.has_animation(anim_name):
		anim_player.remove_animation(anim_name)

	# Create a new animation
	var anim = Animation.new()
	anim.length = 2.0  # Set the duration of the animation to 1 second
	anim.loop_mode = Animation.LOOP_LINEAR
	
	# Add a track to the animation
	var track_index = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_index, str(get_path())+":pos")  # Replace with your node path and property
	anim.track_set_interpolation_type(track_index, Animation.INTERPOLATION_CUBIC)

	# Set keys on the track
	reconstruct_trajectory_track(\
	anim, track_index, \
	rd.angular_momentum, rd.perihelion, rd.standard_gravitational_param)

	# Add or replace the animation in the AnimationPlayer
	anim_player\
	.get_animation_library(animlib_name)\
	.add_animation(anim_name, anim)

	# Optionally, play the animation
	anim_player.play(animlib_name + "/" + anim_name)
	
func _physics_process(delta):
	if attach_point:
		attach_point.position = pos

func calculate_period(h, q, mu):
	var e_and_a = calculate_semi_major_and_eccentricity(h, q, mu)
	var e = e_and_a[0]
	var a = e_and_a[1]
	
	# Update period
	return 2 * PI * sqrt((q / (1 - min(e, 0.99)))**3 / mu)

# Function to reconstruct trajectory in Cartesian coordinates
func reconstruct_trajectory_track(anim, track_id, h, q, mu):

	var T0 = calculate_period(h, q, mu)
	
	# Calculate eccentricity
	var e_and_a = calculate_semi_major_and_eccentricity(h, q, mu)
	var e = e_and_a[0]
	var a = e_and_a[1]
	e = max(e, -1+1e-6)

	# Determine the type of trajectory
	trajectory_type = ""
	if e - 1 < -1e-10:
		trajectory_type = "elliptic"
	elif e - 1 > 1e-10:
		trajectory_type = "hyperbolic"
	else:
		trajectory_type = "parabolic"

	# Define a range of true anomalies
	var r_and_theta = heliocentric_polar_coordinates(T0/2.0, h, q, mu)
	var segments = range(-num_segments/2, num_segments/2+1)
	var theta_max = PI
	match trajectory_type:
		"elliptic":
			#segments.pop_back()
			theta_max = PI
			var n = sqrt(mu / a**3)
			var E_anomaly = 2 * atan2(sqrt((1-e)/(1+e)) * sin(theta_max/2), cos(theta_max/2))
			t_max = (E_anomaly - e * sin(E_anomaly)) / n
			
		"hyperbolic":
			theta_max = min(acos(-1.0 / e)*0.9999, r_and_theta[1])
			var n = sqrt(mu / abs(a)**3.0)
			var F_anomaly = 2.0 * atanh(sqrt((e-1)/(e+1)) * tan(theta_max/2.0))
			t_max = (e * sinh(F_anomaly) - F_anomaly) / n
			anim.track_set_interpolation_loop_wrap(track_id, false)
			
		"parabolic":
			theta_max = r_and_theta[1]
			var D = tan(theta_max / 2.0)
			t_max = (D**3.0 / 3.0 + D) * sqrt(2.0 * q**3 / mu)
			anim.track_set_interpolation_loop_wrap(track_id, false)
		
		_:
			push_error("Invalid trajectory type")

	# Calculate r, x, and y for each theta
	for s in segments:
		var theta_i = theta_max * float(s) / (num_segments/2)
		var r_i = (h * h / mu) / (1.0 + e * cos(theta_i))
		var t_i
		match trajectory_type:
			'elliptic':
				var n = sqrt(mu / a**3)
				var E_anomaly = 2 * atan2(sqrt((1-e)/(1+e)) * sin(theta_i/2), cos(theta_i/2))
				t_i = (E_anomaly - e * sin(E_anomaly)) / n
			
			'hyperbolic':
				var n = sqrt(mu / abs(a)**3.0)
				var F_anomaly = 2.0 * atanh(sqrt((e-1)/(e+1)) * tan(theta_i/2.0))
				t_i = (e * sinh(F_anomaly) - F_anomaly) / n
			
			'parabolic':
				var D = tan(theta_i / 2.0)
				t_i = (D**3.0 / 3.0 + D) * sqrt(2.0 * q**3 / mu)

		var t_i_normed = clamp(t_i / t_max + 1.0, 0.0, 2.0)
		anim.track_insert_key(track_id, t_i_normed\
		, Vector3(r_i*cos(theta_i), r_i*sin(theta_i), 0.0))


# Function to calculate heliocentric polar coordinates
func heliocentric_polar_coordinates(t, h, q, mu):
	# Calculate the semi-major axis and eccentricity
	var e_and_a = calculate_semi_major_and_eccentricity(h, q, mu)
	var e = e_and_a[0]
	var a = e_and_a[1]

	# Determine the type of trajectory
	var trajectory_type = ""
	if e - 1 < -1e-10:
		trajectory_type = "elliptic"
	elif e - 1 > 1e-10:
		trajectory_type = "hyperbolic"
	else:
		trajectory_type = "parabolic"
		
	var r
	var theta
	match trajectory_type:
		"elliptic":
			# Calculate the mean motion
			var n = sqrt(mu / pow(a, 3))

			# Calculate the mean anomaly
			var M = n * t

			# Solve Kepler's equation for E (Eccentric Anomaly)
			var E = solve_keplers_equation(M, e)

			# Compute the radial distance (r)
			r = a * (1 - e * cos(E))

			# Compute the true anomaly (theta) in radians
			theta = 2 * atan2(sqrt(1 + e) * sin(E / 2), sqrt(1 - e) * cos(E / 2))

		"hyperbolic":
			# Calculate the mean motion
			var n = sqrt(mu / pow(abs(a), 3))

			# Calculate the mean anomaly
			var M = n * t
			
			# Solve the hyperbolic Kepler equation for H (Hyperbolic Anomaly)
			var H = solve_hyperbolic_keplers_equation(M, e)

			# Compute the radial distance (r)
			r = -a * (e * cosh(H) - 1)

			# Compute the true anomaly (theta) in radians
			theta = 2 * atan(sqrt((e + 1) / (e - 1)) * tanh(H / 2))

		"parabolic":
			# Calculate the parameter of the parabola
			var p = pow(h,2) / mu

			# Compute the time-related parameter (T)
			var A = 3.0/2.0*sqrt(mu/2/q**3.0)*t
			var B = (A + sqrt(A**2.0+1))**(1.0/3.0)

			# Solve Barker's equation for theta
			theta = 2*atan(B - 1/B)

			# Compute the radial distance (r)
			r = p / (1 + cos(theta))

		_:
			push_error("Invalid trajectory type")

	return [r, theta]

# Function to calculate semi-major axis and eccentricity
func calculate_semi_major_and_eccentricity(h, q, mu):
	# Calculate the semi-major axis and eccentricity
	var e = h**2.0/mu/q-1.0
	var a = q / (1.0 - e)
	return [e, a]

# Function to solve Kepler's Equation
func solve_keplers_equation(M, e):
	# Initial guess for E
	var E = M
	var delta = 1e-6  # convergence criterion
	var MAX_ITER = 1000
	
	# Iterative solution using Newton's method
	for i in range(MAX_ITER):
		var E_new = E + (M + e * sin(E) - E) / (1 - e * cos(E))
		if abs(E_new - E) < delta:
			break
		E = E_new

	return E

# Function to solve the Hyperbolic Kepler's Equation
func solve_hyperbolic_keplers_equation(M, e):
	# Initial guess for H
	var H = M
	var delta = 1e-6  # convergence criterion
	var MAX_ITER = 1000

	# Iterative solution using Newton's method
	for i in range(MAX_ITER):
		var H_new = H + (M - e * sinh(H) + H) / (e * cosh(H) - 1)
		if abs(H_new - H) < delta:
			break
		H = H_new

	return H

func atanh(x: float) -> float:
	if abs(x) >= 1:
		return 0

	return 0.5 * log((1 + x) / (1 - x))
