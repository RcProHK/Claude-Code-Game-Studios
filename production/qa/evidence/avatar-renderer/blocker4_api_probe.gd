extends SceneTree
# Empirical API verification for #26 Avatar Renderer v2-rewrite Blocker 4.
# Answers 3 questions flagged by Pass 3/4 review as "likely LLM hallucination":
#   Q1: AnimatedSprite2D.stop() — resets to frame 0, or "pauses in place"? Does pause() exist?
#   Q2: set_frame_and_progress() — exists? signature?
#   Q3: texture-memory monitor enum — what is the correct name on Compatibility renderer?

func _initialize() -> void:
	print("=== Godot ", Engine.get_version_info().string, " — #26 Blocker 4 API probe ===")

	# ---- Q1 + Q2: AnimatedSprite2D method surface ----
	print("\n[Q1/Q2] AnimatedSprite2D method surface:")
	for m in ["play", "pause", "stop", "set_frame_and_progress", "set_frame", "get_frame", "is_playing"]:
		print("  has_method(%s) = %s" % [m, ClassDB.class_has_method("AnimatedSprite2D", m)])

	# set_frame_and_progress signature
	var methods := ClassDB.class_get_method_list("AnimatedSprite2D", true)
	for md in methods:
		if md.name == "set_frame_and_progress":
			var sig := ""
			for a in md.args:
				sig += "%s: %s, " % [a.name, type_string(a.type)]
			print("  set_frame_and_progress(", sig, ")")

	# ---- Q1 behavioral: stop() vs pause() effect on frame ----
	print("\n[Q1 behavioral] stop() vs pause() effect on current frame:")
	var frames := SpriteFrames.new()
	frames.add_animation(&"run")
	for i in 5:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		frames.add_frame(&"run", ImageTexture.create_from_image(img))

	var s1 := AnimatedSprite2D.new()
	s1.sprite_frames = frames
	get_root().add_child(s1)
	s1.play(&"run")
	s1.set_frame_and_progress(3, 0.5)
	print("  after set_frame_and_progress(3,0.5): frame=", s1.frame, " progress=", s1.frame_progress)
	s1.stop()
	print("  after stop(): frame=", s1.frame, "  playing=", s1.is_playing(), "  -> ", ("RESETS to 0" if s1.frame == 0 else "PAUSES in place"))

	var s2 := AnimatedSprite2D.new()
	s2.sprite_frames = frames
	get_root().add_child(s2)
	s2.play(&"run")
	s2.set_frame_and_progress(3, 0.5)
	if ClassDB.class_has_method("AnimatedSprite2D", "pause"):
		s2.pause()
		print("  after pause(): frame=", s2.frame, "  playing=", s2.is_playing(), "  -> ", ("RESETS to 0" if s2.frame == 0 else "PAUSES in place"))

	# ---- Q3: texture memory monitor enums ----
	print("\n[Q3] Performance integer constants containing 'TEX' or 'MEM':")
	for c in ClassDB.class_get_integer_constant_list("Performance", true):
		if "TEX" in c or "MEM" in c or "VIDEO" in c:
			print("  Performance.", c, " = ", ClassDB.class_get_integer_constant("Performance", c))

	print("\n[Q3] RenderingServer constants containing 'RENDERING_INFO':")
	for c in ClassDB.class_get_integer_constant_list("RenderingServer", true):
		if "RENDERING_INFO" in c:
			print("  RenderingServer.", c, " = ", ClassDB.class_get_integer_constant("RenderingServer", c))

	print("\n=== probe complete ===")
	quit()
