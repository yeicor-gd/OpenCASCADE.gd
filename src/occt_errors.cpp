#include "occt_errors.h"

#include "occt_guard.hxx"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void OcgErrors::_bind_methods() {
    ClassDB::bind_static_method("OcgErrors", D_METHOD("get_last_error_message"), &OcgErrors::get_last_error_message);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("get_last_error_stack"), &OcgErrors::get_last_error_stack);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("get_last_error_type"), &OcgErrors::get_last_error_type);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("take_last_error_message"), &OcgErrors::take_last_error_message);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("take_last_error_stack"), &OcgErrors::take_last_error_stack);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("take_last_error_type"), &OcgErrors::take_last_error_type);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("clear_last_error"), &OcgErrors::clear_last_error);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("set_errors_pushed_on_exception", "enabled"), &OcgErrors::set_errors_pushed_on_exception);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("is_errors_pushed_on_exception"), &OcgErrors::is_errors_pushed_on_exception);
}

String OcgErrors::get_last_error_message() {
    return occt_gd::get_last_error_message();
}

String OcgErrors::get_last_error_stack() {
    return occt_gd::get_last_error_stack();
}

String OcgErrors::get_last_error_type() {
    return occt_gd::get_last_error_type();
}

String OcgErrors::take_last_error_message() {
    return occt_gd::take_last_error_message();
}

String OcgErrors::take_last_error_stack() {
    return occt_gd::take_last_error_stack();
}

String OcgErrors::take_last_error_type() {
    return occt_gd::take_last_error_type();
}

void OcgErrors::clear_last_error() {
    occt_gd::clear_last_error();
}

void OcgErrors::set_errors_pushed_on_exception(bool enabled) {
    occt_gd::set_errors_pushed_on_exception(enabled);
}

bool OcgErrors::is_errors_pushed_on_exception() {
    return occt_gd::errors_pushed_on_exception();
}

} // namespace godot
