# OpenCASCADE.gd

This project provides a GDExtension wrapper for [OpenCASCADE Technology](https://github.com/Open-Cascade-SAS/OCCT) in the Godot Engine.

## Features

- **Cross-Platform Support**: Runs on desktop (Windows, macOS, Linux), mobile (Android, iOS), and web (threads, no threads) platforms.
- **Demo Project**: includes [demo scene](demo/) to get you started quickly.
- **High Performance**: leverages C++ for optimized performance and low-level access.
- **Easy Integration**: drop-in [GDExtension](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html) with simple Godot API bindings.
- **Automated Builds**: uses GitHub Actions for continuous integration, including tests and prebuilt binaries.
- **Dependency Management**: integrated [VCPKG](https://github.com/microsoft/vcpkg) for hassle-free library management.

## Quick Start

1. **Download**: [latest release](https://github.com/yeicor-gd/OpenCASCADE.gd/releases) or [nightly builds](https://github.com/yeicor-gd/OpenCASCADE.gd/actions) (look for `...-addon.zip`).
2. **Extract**: the downloaded `...-addon.zip` into your project's root.
3. **Profit**: see [demo/tests](demo/tests) for examples.

## Using this project as a template for other GDExtensions

1. **Rename the Project**: update `project({old-name} CXX)` in [CMakeLists.txt](CMakeLists.txt), and rename [demo/addons/{old-name}/](demo/addons/OpenCASCADE.gd) to match your new addon name.
2. **Update Dependencies**: modify [vcpkg_ports/gdext/vcpkg.json](vcpkg_ports/gdext/vcpkg.json) to include your required libraries, and link them in [CMakeLists.txt](CMakeLists.txt) following VCPKG instructions.
3. **Customize Builds**: edit [vcpkg_ports/](vcpkg_ports/) and [vcpkg_triplets/](vcpkg_triplets/) as needed to ensure compatibility across platforms.
4. **Implement Your Logic**: add your C++ bindings in [src/](src/), document classes in [doc_classes/](doc_classes/), and create tests/demos in [demo/](demo/) (refer to existing examples).
5. **Update Metadata**: replace placeholders in this README with your project's details and links.
