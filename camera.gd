extends Spatial

var cam_speed = 0.15
var cam_acceleration = 6.0
var cam_direction = Vector3(0.0, 0.0, 0.0)
var cam_velocity = Vector3(0.0, 0.0, 0.0)

var hiddenmap_data = null
var last_mouse_pos3D = null

func _ready():
	# Load and lock map for selection
	var temp_texture = ImageTexture.new()
	var temp_image = Image.new()
	temp_image.load("res://backgroundmap.png")
	temp_texture.create_from_image(temp_image)
	hiddenmap_data = temp_texture.get_data()
	hiddenmap_data.lock()

func _physics_process(delta):
	# Define -1 to +1 direction changes
	cam_direction.x = (-int(Input.is_action_pressed("map_left")) + int(Input.is_action_pressed("map_right")))
	cam_direction.y = (-int(Input.is_action_pressed("map_down")) + int(Input.is_action_pressed("map_up")))
	cam_direction.z = (-int(Input.is_action_pressed("map_zoomin")) + int(Input.is_action_pressed("map_zoomout")))
	cam_direction = cam_direction.normalized()
	
	# Interpolate velocity and modify cam position
	cam_velocity = cam_velocity.linear_interpolate(cam_direction * cam_speed, cam_acceleration * delta)
	$Camera.transform.origin += cam_velocity

func _unhandled_input(event):
	# Handling both hover and click
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if hiddenmap_data == null: return false
		# Get mesh size to detect edges and make conversions
		# This code only support PlaneMesh and QuadMesh
		var quad_mesh_size = $ClickableMap.mesh.size
		
		# Find mouse position in Area
		var from = $Camera.project_ray_origin(event.global_position)
		var dist = 100
		var to = from + $Camera.project_ray_normal(event.global_position) * dist
		var result = get_world().direct_space_state.intersect_ray(from, to, [], $ClickableMap/Area.collision_layer,false,true)
		var mouse_pos3D = null
		if result.size() > 0: mouse_pos3D = result.position
		# Check if the mouse is outside of bounds, use last position to avoid errors
		var is_mouse_inside = mouse_pos3D != null
		if is_mouse_inside:
			# Convert click_pos from world coordinate space to a coordinate space
			mouse_pos3D = $ClickableMap/Area.global_transform.affine_inverse() * mouse_pos3D
			last_mouse_pos3D = mouse_pos3D
		else:
			mouse_pos3D = last_mouse_pos3D
			if mouse_pos3D == null:
				mouse_pos3D = Vector3.ZERO

		# Convert the relative event position from 3D to 2D
		# Could do one-liner but here split for readability
		var mouse_pos2D = Vector2(mouse_pos3D.x, -mouse_pos3D.y)
		mouse_pos2D.x += quad_mesh_size.x / 2.0
		mouse_pos2D.y += quad_mesh_size.y / 2.0
		mouse_pos2D.x = mouse_pos2D.x / (quad_mesh_size.x)
		mouse_pos2D.y = mouse_pos2D.y / (quad_mesh_size.y)
		mouse_pos2D.x = mouse_pos2D.x * 2048.0
		mouse_pos2D.y = mouse_pos2D.y * 1024.0

		# Finally, detect selection
		var pxColour = hiddenmap_data.get_pixel(int(mouse_pos2D.x), int(mouse_pos2D.y))
		if pxColour.r8 == 0:
			# Watch out with Sprite3D depth-sorting
			# It's precise mainly when alpha cut is set to discard
			# Other options (eg. disable) prohibit close z pos between map and selection sprite
			$HoverIreland.visible = true
		else:
			$HoverIreland.visible = false
