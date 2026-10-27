extends "res://tests/asset-toolkit/gameplay.gd"
func run():
	var path="res://assets/optimized/manifest.json" if "--packed" in OS.get_cmdline_user_args() else "res://build/Other Files/Asset Toolkit/gameplay-candidates.json"
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	var found=false
	for item in manifest.assets:
		if item.asset=="sonic":pair(item);found=true
	check(found,"Sonic derivative is registered")
	print("SONIC_IMPORT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
