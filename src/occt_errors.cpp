#include "occt_errors.h"

#include "occt_guard.hxx"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void OcgErrors::_bind_methods() {
    ClassDB::bind_static_method("OcgErrors", D_METHOD("get_last_error_message"), &OcgErrors::get_last_error_message);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("get_last_error_stack"), &OcgErrors::get_last_error_stack);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("take_last_error_message"), &OcgErrors::take_last_error_message);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("take_last_error_stack"), &OcgErrors::take_last_error_stack);
    ClassDB::bind_static_method("OcgErrors", D_METHOD("clear_last_error"), &OcgErrors::clear_last_error);
}

String OcgErrors::get_last_error_message() {
    return occt_gd::get_last_error_message();
}

String OcgErrors::get_last_error_stack() {
    return occt_gd::get_last_error_stack();
}

String OcgErrors::take_last_error_message() {
    return occt_gd::take_last_error_message();
}

String OcgErrors::take_last_error_stack() {
    return occt_gd::take_last_error_stack();
}

void OcgErrors::clear_last_error() {
    occt_gd::clear_last_error();
}

} // namespace godot
