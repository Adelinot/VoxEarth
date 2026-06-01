extends Label

var simulated_ping: float = 30.0
var time_passed: float = 0.0

func _ready():
	add_theme_color_override("font_color", Color.GREEN)
	add_theme_font_size_override("font_size", 18)
	position = Vector2(15, 15)

func _process(delta):
	var fps = Engine.get_frames_per_second()
	
	# Simulates connection variance every 0.3 seconds
	time_passed += delta
	if time_passed >= 0.3:
		time_passed = 0.0
		simulated_ping = clamp(simulated_ping + randf_range(-3.0, 3.0), 25.0, 45.0)
	
	text = "FPS: " + str(fps) + " | Ping: " + str(int(simulated_ping)) + "ms"
