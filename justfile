build-run:
    meson setup build --prefix=/usr/local
    meson compile -C build
    G_MESSAGES_DEBUG=all ./build/src/protonplus