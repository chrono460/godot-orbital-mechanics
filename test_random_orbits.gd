extends Node3D

var animated_orbit_scene = preload("res://orbit_motion_bezier.tscn")
var physical_orbit_scene = preload("res://orbit_motion_physics.tscn")

@export var num_orbits_to_gen: int = 1
@export var animated : bool = false
@export var generate_orbits : bool :
	set(val):
		if val:
			generate_orbits = false
			for i in range(num_orbits_to_gen):
				if animated:
					var new_orbit = animated_orbit_scene.instantiate()
					new_orbit.tree_entered.connect(new_orbit.set_owner.bind(self))
					add_child(new_orbit)
					
					new_orbit.rd.angular_momentum = randf_range(0.5,2.0)
					new_orbit.rd.perihelion = randf_range(1.0,2.0)
					new_orbit.transform = _generate_randomly_rotated_basis()
					new_orbit.anim_player.speed_scale = max(0.1,1.0 / new_orbit.t_max)
					
					var debug_mesh = MeshInstance3D.new()
					debug_mesh.mesh = SphereMesh.new()
					var material = StandardMaterial3D.new()
					material.albedo_color = Color(\
					 randf_range(0.1, 1.0)\
					,randf_range(0.1, 1.0)\
					,randf_range(0.1, 1.0))
					debug_mesh.mesh.material = material
					debug_mesh.tree_entered.connect(\
					debug_mesh.set_owner.bind(self))
					new_orbit.add_child(debug_mesh)
					new_orbit.attach_point = debug_mesh
					
				else:
					var new_orbit = physical_orbit_scene.instantiate()
					new_orbit.tree_entered.connect(new_orbit.set_owner.bind(self))
					add_child(new_orbit)
					
					var debug_mesh = MeshInstance3D.new()
					debug_mesh.mesh = SphereMesh.new()
					var material = StandardMaterial3D.new()
					material.albedo_color = Color(\
					 randf_range(0.1, 1.0)\
					,randf_range(0.1, 1.0)\
					,randf_range(0.1, 1.0))
					debug_mesh.mesh.material = material
					debug_mesh.tree_entered.connect(\
					debug_mesh.set_owner.bind(self))
					new_orbit.add_child(debug_mesh)
					new_orbit.attach_point = debug_mesh
					
					var p_dot_v = 1.0
					var pos
					var vel
					while abs(p_dot_v) > 0.5:
						pos = Vector3(randf_range(-5,5),randf_range(-1,1),randf_range(-5,5)).normalized()
						pos *= 5
						vel = Vector3(randfn(0,1),randfn(0,0.2),randfn(0,1))
						if pos.length() < 1e-6 || vel.length() < 1e-6:
							p_dot_v = 1.0
						else:
							p_dot_v = pos.dot(vel)/pos.length()/vel.length()
					var h = (pos.cross(vel)).length()
					vel = vel / h * randf_range(1.25, 4.0)
					new_orbit.pos = pos
					new_orbit.vel = vel
					new_orbit.simulation_speed = 1.0

func _ready():
	num_orbits_to_gen = 1000
	animated = true
	generate_orbits = true

func _generate_randomly_rotated_basis():
	var random_axis = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
	while random_axis.length() < 0.01:
		random_axis = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
	var random_angle = randf_range(0, 2 * PI)
	return Basis(random_axis, random_angle)

