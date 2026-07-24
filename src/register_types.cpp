// register_types.cpp - Entry point for OpenCASCADE.gd GDExtension

#include "register_types.h"

// Autowrapper-generated module registration
#include "autowrapper/module.h"

static void opencascade_gd_initialize(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

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
