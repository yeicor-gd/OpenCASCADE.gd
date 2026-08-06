extends Node

# Tests for OCCT default parameter values being exposed to GDScript via
# ClassDB DEFVAL bindings: methods can be called with fewer arguments.
#
# Note: OCCT string APIs use 1-based indexing (indices start at 1).


func test_ascii_string_token_default() -> String:
	# Token(separators, whichone=1) — 'whichone' has a default of 1.
	var s := OcgTCollectionHAsciiString.from_f("a.b.c")
	if s == null:
		return "Failed to create AsciiString"
	var t1: Variant = s.token(".")
	if not t1 is OcgTCollectionHAsciiString:
		return "Token('.') should return an AsciiString, got %s" % t1
	var t2: Variant = s.token(".", 2)
	var t3: Variant = s.token(".", 3)
	if (t1 as OcgTCollectionHAsciiString).to_c_string() != "a":
		return "Token('.') default whichone=1 should be 'a', got '%s'" % (t1 as OcgTCollectionHAsciiString).to_c_string()
	if (t2 as OcgTCollectionHAsciiString).to_c_string() != "b":
		return "Token('.', 2) should be 'b', got '%s'" % (t2 as OcgTCollectionHAsciiString).to_c_string()
	if (t3 as OcgTCollectionHAsciiString).to_c_string() != "c":
		return "Token('.', 3) should be 'c', got '%s'" % (t3 as OcgTCollectionHAsciiString).to_c_string()
	return "OK"


func test_ascii_string_remove_default() -> String:
	# Remove(where, ahowmany=1) — 'ahowmany' has a default of 1.
	var s := OcgTCollectionHAsciiString.from_f("Hello World")
	if s == null:
		return "Failed to create AsciiString"
	s.remove(1)
	if s.to_c_string() != "ello World":
		return "Remove(1) with default count should yield 'ello World', got '%s'" % s.to_c_string()
	s.remove(1, 4)
	if s.to_c_string() != " World":
		return "Remove(1, 4) should yield ' World', got '%s'" % s.to_c_string()
	return "OK"


func test_ascii_string_changeall_default() -> String:
	# ChangeAll(aChar, NewChar, CaseSensitive=true) — bool default.
	var s := OcgTCollectionHAsciiString.from_f("a.b.c")
	if s == null:
		return "Failed to create AsciiString"
	s.change_all(46, 32)  # '.' -> ' ' with default CaseSensitive=true
	if s.to_c_string() != "a b c":
		return "ChangeAll with default CaseSensitive should yield 'a b c', got '%s'" % s.to_c_string()
	# Explicit CaseSensitive=false must still be honoured: it replaces 'A'
	# regardless of case, so 'a' is also replaced.
	var t := OcgTCollectionHAsciiString.from_f("A.a")
	t.change_all(65, 90, false)  # 'A' -> 'Z', case-insensitive
	if t.to_c_string() != "Z.Z":
		return "ChangeAll explicit CaseSensitive=false should yield 'Z.Z', got '%s'" % t.to_c_string()
	return "OK"


func test_mmgr_all_defaulted_args() -> String:
	# StandardMMgrOpt(from_w) — every parameter has a default; calling with
	# zero arguments must construct a valid instance.
	var opts := OcgStandardMMgrOpt.from_w()
	if opts == null:
		return "from_w() with all defaults failed"
	# Explicitly passing the defaults must produce the same behaviour.
	var opts2 := OcgStandardMMgrOpt.from_w(true, true, 200, 10000, 40000)
	if opts2 == null:
		return "from_w() with explicit defaults failed"
	return "OK"


func test_dump_json_default_depth() -> String:
	# DumpJson(theDepth=-1) — returns a String, exercises an int default.
	var pnt := OcgGpPnt.from_6(1.0, 2.0, 3.0)
	var json1: Variant = pnt.dump_json()
	if not json1 is String:
		return "DumpJson() should return a String, got %s" % json1
	var json2: Variant = pnt.dump_json(-1)
	if json1 != json2:
		return "DumpJson() default depth should equal DumpJson(-1)"
	if not (json1 as String).contains("gp_Pnt"):
		return "DumpJson() output should mention the type"
	return "OK"


func test_tdf_transaction_string_default() -> String:
	# TDF_Transaction(aName="") — a string-typed default; the zero-arg
	# call must construct a valid (anonymous) transaction.
	var mtr := OcgTDFTransaction.new()
	if mtr == null:
		return "new() anonymous transaction failed"
	var tr2 := OcgTDFTransaction.from_Q(OcgTCollectionAsciiString.from_f("my-name"))
	if tr2 == null:
		return "from_Q('my-name') failed"
	return "OK"


func test_messenger_enum_default() -> String:
	# Send(theString, theGravity) — the enum argument must be passed
	# explicitly (the default Message_Warning is not bound).
	var m := OcgMessageMessenger.new()
	if m == null:
		return "Failed to create Message_Messenger"
	m.send_x("default-gravity", OcgEnums.Message_Gravity.Message_Warning)
	m.send_x("explicit-gravity", OcgEnums.Message_Gravity.Message_Info)
	return "OK"


func test_gradient_background_enum_default() -> String:
	# SetColors(c1, c2, theMethod) — the enum argument must be passed
	# explicitly (the default is not bound).
	var bg := OcgAspectGradientBackground.new()
	if bg == null:
		return "Failed to create Aspect_GradientBackground"
	var c1 := OcgQuantityColor.from_W(1.0, 0.0, 0.0, OcgEnums.Quantity_TypeOfColor.Quantity_TOC_RGB)
	var c2 := OcgQuantityColor.from_W(0.0, 0.0, 1.0, OcgEnums.Quantity_TypeOfColor.Quantity_TOC_RGB)
	bg.set_colors(c1, c2, OcgEnums.Aspect_GradientFillMethod.Aspect_GradientFillMethod_Horizontal)
	bg.set_colors(c1, c2, OcgEnums.Aspect_GradientFillMethod.Aspect_GradientFillMethod_Elliptical)
	return "OK"
