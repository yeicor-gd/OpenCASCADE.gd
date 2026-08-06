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
    static String get_last_error_type();
    static String take_last_error_message();
    static String take_last_error_stack();
    static String take_last_error_type();
    static void clear_last_error();
    static void set_errors_pushed_on_exception(bool enabled);
    static bool is_errors_pushed_on_exception();

protected:
    static void _bind_methods();
};

} // namespace godot

#endif // OCCT_ERRORS_H
