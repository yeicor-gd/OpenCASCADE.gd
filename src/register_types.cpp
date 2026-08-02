// register_types.cpp - Entry point for OpenCASCADE.gd GDExtension

#include "register_types.h"

// Autowrapper-generated module registration
#include "autowrapper/module.h"
#include "occt_errors.h"
#include "occt_console_printer.hpp"

#include <Message.hxx>
#include <OSD.hxx>

#include <godot_cpp/core/class_db.hpp>

static void opencascade_gd_initialize(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // Convert OCCT C-style signals (SIGSEGV, SIGBUS, ...) into C++ exceptions
    // so that the generated wrapper try/catch guards can turn them into Godot
    // errors instead of crashing the process. Floating-point traps are left
    // disabled (theFloatingSignal=false) so harmless NaN computations don't
    // raise spurious SIGFPE. Safe to call repeatedly.
    OSD::SetSignal(false);

    // Replace OCCT's default console printer (which writes to std::cout and
    // crashes inside Godot due to the mixed libstdc++ ABI — see
    // occt_console_printer.hpp) with a safe C-stdio-based printer, so internal
    // OCCT messages (warnings, reader errors, ...) stay visible without
    // terminating the process.
    occt_gd::install_safe_console_printer(Message::DefaultMessenger());

    // Register the GDScript-facing diagnostics API (reads the last-error state
    // recorded by the wrapper exception guards).
    godot::ClassDB::register_class<godot::OcgErrors>();

    // Register autowrapper-generated classes
    gdext_initialize_module_auto(p_level);
}

static void opencascade_gd_uninitialize(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    gdext_uninitialize_module_auto(p_level);
}

extern "C" {
    GDExtensionBool GDE_EXPORT gdext_library_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization
    ) {
        const godot::GDExtensionBinding::InitObject init_obj(
            p_get_proc_address, p_library, r_initialization
        );

        init_obj.register_initializer(opencascade_gd_initialize);
        init_obj.register_terminator(opencascade_gd_uninitialize);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}
