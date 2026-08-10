// Hand-written implementation of the safe OCCT console printer. See the
// declaration in occt_console_printer.hpp for the rationale.

#include "occt_console_printer.hpp"

#include <cstdio>
#include <iostream>
#if defined(__GLIBCXX__)
#include <ext/stdio_sync_filebuf.h>
#endif

#include <Message_Printer.hxx>
#include <TCollection_AsciiString.hxx>

namespace occt_gd {

namespace {

// A Message_Printer that emits messages as plain text on stdout using C stdio,
// deliberately avoiding the std::ostream layer (see install_safe_console_printer).
class SafeConsolePrinter final : public ::Message_Printer {
public:
    SafeConsolePrinter() = default;

protected:
    void send(const TCollection_AsciiString &theString, const Message_Gravity) const override {
        fputs(theString.ToCString(), stdout);
        fputc('\n', stdout);
    }
};

// When Godot (which statically embeds its own libstdc++) is the main executable,
// the system libstdc++.so.6's std::cout is never constructed: its static
// ios_base::Init initializes the *interposed* copy (Godot's), leaving the
// shared-library std::cout as a zeroed BSS object with a NULL vptr. OCCT's
// Message_PrinterOStream points at that unconstructed std::cout, so both its
// send() and Close() (which flushes) dereference the NULL vptr and SIGSEGV.
// This reconstructs the shared std::cout in place so those paths are safe
// (send() prints, Close() flushes) regardless of libstdc++ interposition.
void ensure_functional_shared_cout() {
#if !defined(__GLIBCXX__)
    // libc++/MSVC STL do not interpose std::cout the way libstdc++ does, and
    // do not ship __gnu_cxx::stdio_sync_filebuf, so there is nothing to fix.
    return;
#endif
    if (*reinterpret_cast<const void **>(&std::cout) != nullptr) {
        return; // already constructed
    }
    static __gnu_cxx::stdio_sync_filebuf<char> s_stdout_buf(stdout);
    new (&std::cout) std::ostream(&s_stdout_buf);
}

} // namespace

void install_safe_console_printer(const opencascade::handle<::Message_Messenger> &theMessenger) {
    if (theMessenger.IsNull()) {
        return;
    }

    // The messenger's default Message_PrinterOStream holds a pointer to the
    // (normally unconstructed) shared std::cout; make it functional before it
    // is destroyed below by ChangePrinters().Clear() (destructor flushes).
    ensure_functional_shared_cout();

    theMessenger->ChangePrinters().Clear();
    theMessenger->AddPrinter(new SafeConsolePrinter());
}

} // namespace occt_gd
