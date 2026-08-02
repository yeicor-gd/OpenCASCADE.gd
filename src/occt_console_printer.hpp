// Hand-written OCCT message printer that bypasses std::ostream.
#pragma once

#include <Message_Messenger.hxx>

namespace occt_gd {

// Replaces the printer set of a Message_Messenger with a single safe printer
// that writes to stdout via C stdio (fputs) instead of std::ostream.
//
// OCCT's default Message_PrinterOStream writes to std::cout. Inside a Godot
// process this is unsafe: Godot statically links its own libstdc++ while the
// OCCT shared libraries link the system libstdc++.so.6, so libstdc++'s static
// ios_base::Init initializes the *interposed* copy of std::cout (Godot's),
// leaving the shared-library std::cout that OCCT references as an unconstructed
// NULL-vptr BSS object. Any OCCT message (or the printer's destructor, which
// flushes) would then SIGSEGV. We reconstruct that shared std::cout in place
// and swap the messenger's printers for ones that use C stdio only.
void install_safe_console_printer(const opencascade::handle<::Message_Messenger> &theMessenger);

} // namespace occt_gd
