// Hand-written GDScript-facing diagnostics API for OCCT wrapper errors.
// Reads the last-error state recorded by the force-included occt_guard.hxx
// when a caught OCCT exception is converted into a Godot error.
#ifndef OCCT_ERRORS_H
#define OCCT_ERRORS_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class OcgErrors : public RefCounted {
    GDCLASS(OcgErrors, RefCounted)

public:
    static String get_last_error_message();
    static String get_last_error_stack();
    static String take_last_error_message();
    static String take_last_error_stack();
    static void clear_last_error();

protected:
    static void _bind_methods();
};

} // namespace godot

#endif // OCCT_ERRORS_H
