extends Node


func test_allocator_type_enum_constants() -> String:
	if OcgStandard.AllocatorType.NATIVE != 0:
		return "AllocatorType.NATIVE expected 0 got %s" % OcgStandard.AllocatorType.NATIVE
	if OcgStandard.AllocatorType.OPT != 1:
		return "AllocatorType.OPT expected 1 got %s" % OcgStandard.AllocatorType.OPT
	if OcgStandard.AllocatorType.TBB != 2:
		return "AllocatorType.TBB expected 2 got %s" % OcgStandard.AllocatorType.TBB
	if OcgStandard.AllocatorType.JEMALLOC != 3:
		return "AllocatorType.JEMALLOC expected 3 got %s" % OcgStandard.AllocatorType.JEMALLOC
	return "OK"


func test_allocator_type_static() -> String:
	var alloc := OcgStandard.get_allocator_type()
	if alloc != OcgStandard.AllocatorType.NATIVE:
		return "GetAllocatorType expected NATIVE got %s" % alloc
	return "OK"


func test_guid_format_check() -> String:
	if not OcgStandardGUID.check_guid_format("00000000-0000-0000-0000-000000000000"):
		return "CheckGUIDFormat rejected the null UUID"
	if OcgStandardGUID.check_guid_format("not-a-uuid"):
		return "CheckGUIDFormat accepted a malformed string"
	return "OK"


func test_guid_roundtrip() -> String:
	var guid := OcgStandardGUID.from_f("00000000-0000-0000-0000-000000000000")
	if guid == null:
		return "Failed to parse the null UUID string"
	var uuid := guid.to_uuid()
	if uuid == null:
		return "ToUUID returned null"
	var back := OcgStandardGUID.from_n(uuid)
	if back == null:
		return "GUID(UUID) reconstruction failed"
	if not guid.is_same(back):
		return "Round-tripped GUID should IsSame the original"
	if guid.is_not_same(back):
		return "IsNotSame should be false for identical GUIDs"
	return "OK"


func test_exception_diagnostics() -> String:
	var failure := OcgStandardFailure.new()
	if failure == null:
		return "Failed to construct Standard_Failure"
	if failure.exception_type() != "Standard_Failure":
		return "exception_type expected Standard_Failure got %s" % failure.exception_type()
	var oob := OcgStandardOutOfRange.new()
	if oob == null:
		return "Failed to construct Standard_OutOfRange"
	if oob.exception_type() != "Standard_OutOfRange":
		return "exception_type expected Standard_OutOfRange got %s" % oob.exception_type()
	return "OK"


func test_transient_type_system() -> String:
	var tr := OcgStandardTransient.new()
	if tr == null:
		return "Failed to construct Standard_Transient"
	if tr.get_ref_count() < 1:
		return "Fresh Standard_Transient refcount should be >= 1 got %s" % tr.get_ref_count()
	var tname := OcgStandardTransient.get_type_name()
	if tname != "Standard_Transient":
		return "Standard_Transient::get_type_name expected 'Standard_Transient' got '%s'" % tname
	var td := OcgStandardTransient.get_type_descriptor()
	if td == null:
		return "get_type_descriptor returned null"
	return "OK"
