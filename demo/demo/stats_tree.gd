extends Tree

func _on_flag_stats_changed(stats: Dictionary) -> void:
	clear()
	set_column_title(0, "Name")
	set_column_expand(0, true)
	set_column_title(1, "MS")
	set_column_expand(1, false)
	set_column_custom_minimum_width(1, 50)
	set_column_title(2, "FPS")
	set_column_expand(2, false)
	set_column_custom_minimum_width(2, 60)
	var root := create_item()
	_add_stats(root, stats)

func _add_stats(root: TreeItem, stats: Dictionary):
	for ch in stats["children"]:
		var it := root.create_child()
		it.set_text(0, ch["name"])
		it.set_text(1, "%.2f" % (ch["us"] / 1000.0))
		it.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		it.set_text(2, "%.0f" % (1000000.0 / ch["us"]))
		it.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
		if "children" in ch:
			_add_stats(it, ch)
