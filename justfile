VER := `dasel -i toml 'package.version' < typst.toml | tr -d "'"`
DIST_DIR := "dist/spaniel/" + VER
LOCAL_PACKAGES_MACOS := "$HOME/Library/Application Support/typst/packages/local"

mod package "./justscripts/package"

assets:
    #!/usr/bin/env bash
    set -euo pipefail

    cd assets
    
    # typst c --ppi 300 sheet.typ sheet.png
    # typst c --ppi 300 banner.typ banner.png
    # typst c --ppi 300 --input "banner=github" banner.typ banner_1280_640.png
    
    # oxipng *.png

examples:
  # typst c examples/*.typ --root .. --format png --ppi 300
  # oxipng examples/*.png

manual *args:
    typst c --root . manual/manual.typ --input version="{{VER}}" {{ args }}

bundle: assets
    rm -rf dist
    mkdir -p "{{ DIST_DIR }}/src"

    cp -r src/* "{{ DIST_DIR }}/src"
    cp LICENSE "{{ DIST_DIR }}"
    cp README.md "{{ DIST_DIR }}"
    cp typst.toml "{{ DIST_DIR }}"

[macos]
install-dist: bundle
    rm -rf "{{ LOCAL_PACKAGES_MACOS }}/spaniel"
    mkdir -p "{{ LOCAL_PACKAGES_MACOS }}/spaniel"
    cp -r "{{ DIST_DIR }}" "{{ LOCAL_PACKAGES_MACOS }}/spaniel"

clean:
    rm -f examples/*.png


