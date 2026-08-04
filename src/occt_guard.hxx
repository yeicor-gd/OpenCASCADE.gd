// Hand-written exception guard helpers for the generated OCCT wrappers.
// Force-included (via CMake) into every generated translation unit.  Each
// generated file includes its own OCCT headers, so this header must only rely
// on the OCCT headers it includes below.  DO NOT edit the generated files to
// depend on this header explicitly — it is force-included into every generated
// translation unit.
#pragma once

#include <exception>

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/string.hpp>

#include <Standard_ErrorHandler.hxx>
#include <Standard_Failure.hxx>

// Safe-console printer declaration: generated wrapper code calls
// occt_gd::install_safe_console_printer() (e.g. in the Message_Messenger
// constructor) so OCCT messages never reach the crash-prone std::cout path.
#include "occt_console_printer.hpp"

namespace occt_gd {

struct LastError {
    ::godot::String message;
    ::godot::String stack;
};

// Thread-local so concurrent Godot threads (Servers, etc.) don't clobber each
// other's last-error diagnostics.
inline LastError &last_error_ref() {
    thread_local LastError err;
    return err;
}

inline void record_last_exception(const char *p_message, const char *p_stack) {
    LastError &err = last_error_ref();
    err.message = p_message ? ::godot::String(p_message) : ::godot::String();
    err.stack = p_stack ? ::godot::String(p_stack) : ::godot::String();
}

inline ::godot::String get_last_error_message() {
    return last_error_ref().message;
}

inline ::godot::String get_last_error_stack() {
    return last_error_ref().stack;
}

inline ::godot::String take_last_error_message() {
    ::godot::String out = last_error_ref().message;
    last_error_ref().message = ::godot::String();
    return out;
}

inline ::godot::String take_last_error_stack() {
    ::godot::String out = last_error_ref().stack;
    last_error_ref().stack = ::godot::String();
    return out;
}

inline void clear_last_error() {
    last_error_ref().message = ::godot::String();
    last_error_ref().stack = ::godot::String();
}

} // namespace occt_gd

// Catch epilogue for generated default constructors. A constructor has no
// return value and cannot return null on failure, so the exception is recorded
// (readable via OcgErrors.get_last_error_message()) and construction completes
// with the object in a safe, null-native state (methods null-check before use).
#define OCCT_GUARD_CATCH_CTOR()                                                                 \
    catch (const Standard_Failure &occt_gd_sf) {                                              \
        occt_gd::record_last_exception(occt_gd_sf.what(), occt_gd_sf.GetStackString());       \
    } catch (const std::exception &occt_gd_e) {                                               \
        occt_gd::record_last_exception(occt_gd_e.what(), nullptr);                            \
    } catch (...) {                                                                           \
        occt_gd::record_last_exception("Unknown OCCT/GDExtension exception", nullptr);        \
    }

// Catch epilogue for generated NON-void wrapper methods. Must be written as
//   } OCCT_GUARD_CATCH(<default>);
// directly after the try block that contains the body (and OCC_CATCH_SIGNALS,
// so OCCT signal-to-exception conversion also lands here). The default value
// is `{}` (value-init) which compiles for every wrapper return type.
#define OCCT_GUARD_CATCH(m_default)                                                           \
    catch (const Standard_Failure &occt_gd_sf) {                                              \
        occt_gd::record_last_exception(occt_gd_sf.what(), occt_gd_sf.GetStackString());       \
        ERR_FAIL_V_MSG(m_default, occt_gd_sf.what());                                         \
    } catch (const std::exception &occt_gd_e) {                                               \
        occt_gd::record_last_exception(occt_gd_e.what(), nullptr);                            \
        ERR_FAIL_V_MSG(m_default, occt_gd_e.what());                                          \
    } catch (...) {                                                                           \
        occt_gd::record_last_exception("Unknown OCCT/GDExtension exception", nullptr);        \
        ERR_FAIL_V_MSG(m_default, "Unknown OCCT/GDExtension exception");                      \
    }

// Catch epilogue for generated VOID wrapper methods.
#define OCCT_GUARD_CATCH_VOID()                                                               \
    catch (const Standard_Failure &occt_gd_sf) {                                              \
        occt_gd::record_last_exception(occt_gd_sf.what(), occt_gd_sf.GetStackString());       \
        ERR_FAIL_MSG(occt_gd_sf.what());                                                      \
    } catch (const std::exception &occt_gd_e) {                                               \
        occt_gd::record_last_exception(occt_gd_e.what(), nullptr);                            \
        ERR_FAIL_MSG(occt_gd_e.what());                                                       \
    } catch (...) {                                                                           \
        occt_gd::record_last_exception("Unknown OCCT/GDExtension exception", nullptr);        \
        ERR_FAIL_MSG("Unknown OCCT/GDExtension exception");                                   \
    }
