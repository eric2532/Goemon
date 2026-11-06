extends "res://tests/asset-toolkit/gameplay.gd"
func run():
	var staged=JSON.parse_string(FileAccess.get_file_as_string("res://assets/optimized/manifest.json" if "--packed" in OS.get_cmdline_user_args() else "res://build/Other Files/Asset Toolkit/gameplay-candidates.json"))
	var matched=[]
	for item in staged.assets:
		if not item.asset.begins_with("warcraft-"):continue
		matched.append(item.asset)
		pair(item)
		print("WARCRAFT_IMPORTED ",item.asset," checks=",checks," failures=",failures)
		await process_frame
	for id in ["warcraft-blademaster","warcraft-demon-hunter","warcraft-peasant","warcraft-mountain-king"]:check(matched.has(id),"Warcraft export registered: "+id)
	print("WARCRAFT_IMPORTED_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
