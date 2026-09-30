/*! coi-serviceworker v0.1.7 - Guido Zuidhof and contributors, licensed under MIT */
let coepCredentialless = false;
if (typeof window === 'undefined') {
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

    self.addEventListener("message", (ev) => {
        if (!ev.data) {
            return;
        } else if (ev.data.type === "deregister") {
            self.registration
                .unregister()
                .then(() => {
                    return self.clients.matchAll();
                })
                .then(clients => {
                    clients.forEach((client) => client.navigate(client.url));
                });
        } else if (ev.data.type === "coepCredentialless") {
            coepCredentialless = ev.data.value;
        }
    });

    self.addEventListener("fetch", function (event) {
        const r = event.request;
        if (r.cache === "only-if-cached" && r.mode !== "same-origin") {
            return;
        }

        const request = (coepCredentialless && r.mode === "no-cors")
            ? new Request(r, {
                credentials: "omit",
            })
            : r;
        event.respondWith(
            fetch(request)
                .then((response) => {
                    if (response.status === 0) {
                        return response;
                    }

                    const newHeaders = new Headers(response.headers);
                    newHeaders.set("Cross-Origin-Embedder-Policy",
                        coepCredentialless ? "credentialless" : "require-corp"
                    );
                    if (!coepCredentialless) {
                        newHeaders.set("Cross-Origin-Resource-Policy", "cross-origin");
                    }
                    newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");

                    // GDExtension side modules for Web are Emscripten .so files
                    // that are actually WebAssembly.  GitHub Pages serves them as
                    // application/x-sharedlib or octet-stream which makes
                    // instantiateStreaming (used by the loader) reject them.
                    if (new URL(event.request.url).pathname.includes('.wasm32.so')) {
                        newHeaders.set("Content-Type", "application/wasm");
                    }

                    return new Response(response.body, {
                        status: response.status,
                        statusText: response.statusText,
                        headers: newHeaders,
                    });
                })
                .catch((e) => console.error(e))
        );
    });

} else {
    (() => {
        // You can customize the behavior of this script through a global `coi` variable.
        const coi = {
            shouldRegister: () => true,
            shouldDeregister: () => false,
            coepCredentialless: () => !(window.chrome || window.netscape),
            doReload: () => window.location.reload(),
            quiet: false,
            ...window.coi
        };

        const n = navigator;

        if (n.serviceWorker && n.serviceWorker.controller) {
            n.serviceWorker.controller.postMessage({
                type: "coepCredentialless",
                value: coi.coepCredentialless(),
            });

            if (coi.shouldDeregister()) {
                n.serviceWorker.controller.postMessage({ type: "deregister" });
            }
        }

        // If we're already coi: do nothing. Perhaps it's due to this script doing its job, or COOP/COEP are
        // already set from the origin server. Also if the browser has no notion of crossOriginIsolated, just give up here.
        if (window.crossOriginIsolated !== false || !coi.shouldRegister()) return;

        if (!window.isSecureContext) {
            !coi.quiet && console.log("COOP/COEP Service Worker not registered, a secure context is required.");
            return;
        }

        // In some environments (e.g. Chrome incognito mode) this won't be available
        if (n.serviceWorker) {
            n.serviceWorker.register(window.document.currentScript.src).then(
                async (registration) => {
                    !coi.quiet && console.log("COOP/COEP Service Worker registered", registration.scope);

                    // Only reload on updatefound when updating an existing active SW,
                    // not during first install — the first install reload is handled
                    // by the cross-origin-isolation check below.  Without this
                    // guard, Chrome can enter a forever refresh loop: updatefound
                    // fires during initial registration, reloads before the SW takes
                    // control, then on the new load the SW still isn't controlling,
                    // so it registers again and updatefound fires again.
                    if (registration.active) {
                        registration.addEventListener("updatefound", () => {
                            !coi.quiet && console.log("Reloading page to make use of updated COOP/COEP Service Worker.");
                            coi.doReload();
                        });
                    }

                    // If the document is not cross-origin isolated yet, it was served
                    // before the service worker could add the COOP/COEP headers to it
                    // (first visit, or the SW took control mid-load).  Wait until the
                    // SW is active and controlling the page, then reload so the SW can
                    // serve the navigation with the COOP/COEP headers.  A per-session
                    // counter (persisted across reloads in sessionStorage) allows a few
                    // retries in case a reload races the SW activation, but prevents an
                    // infinite reload loop if cross-origin isolation can't be achieved.
                    await Promise.race([
                        n.serviceWorker.ready,
                        new Promise((resolve) => setTimeout(resolve, 10000)),
                    ]);
                    if (!n.serviceWorker.controller) {
                        await Promise.race([
                            new Promise((resolve) => {
                                n.serviceWorker.addEventListener("controllerchange", resolve, { once: true });
                            }),
                            new Promise((resolve) => setTimeout(resolve, 5000)),
                        ]);
                    }
                    if (window.crossOriginIsolated === false) {
                        const RELOAD_KEY = "coi-reload-count";
                        let reloadCount = 0;
                        try {
                            reloadCount = parseInt(window.sessionStorage.getItem(RELOAD_KEY) || "0", 10) || 0;
                        } catch (e) { /* sessionStorage may be unavailable */ }
                        if (reloadCount < 3) {
                            try {
                                window.sessionStorage.setItem(RELOAD_KEY, String(reloadCount + 1));
                            } catch (e) { /* ignore */ }
                            !coi.quiet && console.log("Reloading page to make use of the cross-origin-isolated COOP/COEP Service Worker.");
                            coi.doReload();
                        }
                    }
                },
                (err) => {
                    !coi.quiet && console.error("COOP/COEP Service Worker failed to register:", err);
                }
            );
        }
    })();
}
