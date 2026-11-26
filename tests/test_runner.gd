extends Node

func _ready() -> void:
	print("\n==================================================")
	print("       SUBWAY SIMULATOR - AUTOMATED TEST SUITE    ")
	print("==================================================\n")
	
	var test_files: Array[String] = [
		"res://tests/unit/test_line_connection.gd",
		"res://tests/unit/test_boarding_rule.gd",
		"res://tests/unit/test_congestion_game_over.gd",
		"res://tests/unit/test_terrain_checking.gd",
		"res://tests/unit/test_seed_map.gd",
		"res://tests/integration/test_network_and_pathfinding.gd",
		"res://tests/integration/test_train_stop_cycle.gd",
		"res://tests/integration/test_save_load_lifecycle.gd",
		"res://tests/smoke/test_main_scene_simulation.gd",
	]
	
	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	var failures: Array[Dictionary] = []
	
	for path in test_files:
		var script = load(path)
		if script == null:
			print("[ERROR] Failed to load test script: %s" % path)
			failed_tests += 1
			continue
		
		var test_instance = script.new()
		print("--- Running: %s ---" % path.get_file())
		
		if test_instance.has_method("run_all"):
			var results: Array = test_instance.run_all()
			for r in results:
				total_tests += 1
				if r.get("passed", false):
					passed_tests += 1
					print("  [PASS] %s" % r.get("test", "Unknown"))
				else:
					failed_tests += 1
					print("  [FAIL] %s - %s" % [r.get("test", "Unknown"), r.get("reason", "")])
					failures.append(r)
		else:
			print("  [WARN] No run_all() method found in %s" % path)
		
		if test_instance is Node:
			test_instance.free()
	
	print("\n==================================================")
	print("TEST SUMMARY: Total: %d | Passed: %d | Failed: %d" % [total_tests, passed_tests, failed_tests])
	print("==================================================\n")
	
	if failed_tests > 0:
		print("❌ SOME TESTS FAILED!")
		get_tree().quit(1)
	else:
		print("✅ ALL TESTS PASSED SUCCESSFULLY!")
		get_tree().quit(0)
