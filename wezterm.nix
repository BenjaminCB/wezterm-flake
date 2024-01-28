{ pkgs }:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "wezterm";
  version = "20240127-113634-bbcac864";

  src = pkgs.fetchFromGitHub {
    owner = "wez";
    repo = pname;
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-B6AakLbTWIN123qAMQk/vFN83HHNRSNkqicNRU1GaCc=";
  };

  postPatch = ''
    echo ${version} > .tag

    # tests are failing with: Unable to exchange encryption keys
    rm -r wezterm-ssh/tests
  '';

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "image-0.24.5" = "sha256-fTajVwm88OInqCPZerWcSAm1ga46ansQ3EzAmbT58Js=";
      "xcb-1.2.1" = "sha256-zkuW5ATix3WXBAj2hzum1MJ5JTX3+uVQ01R1vL6F1rY=";
      "xcb-imdkit-0.2.0" = "sha256-L+NKD0rsCk9bFABQF4FZi9YoqBHr4VAZeKAWgsaAegw=";
    };
  };

  nativeBuildInputs = with pkgs; [
    installShellFiles
    ncurses # tic for terminfo
    pkg-config
    python3
  ] ++ pkgs.lib.optional pkgs.stdenv.isDarwin perl;

  buildInputs = with pkgs; [
    fontconfig
    zlib
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    xorg.libX11
    xorg.libxcb
    libxkbcommon
    openssl
    wayland
    xorg.xcbutil
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilwm # contains xcb-ewmh among others
  ]) ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    Cocoa
    CoreGraphics
    Foundation
    libiconv
    System
    UserNotifications
  ];

  buildFeatures = [ "distro-defaults" ];

  # env.NIX_LDFLAGS = pkgs.lib.optionalString pkgs.stdenv.isDarwin "-framework System";

  postInstall = ''
    mkdir -p $out/nix-support
    echo "${passthru.terminfo}" >> $out/nix-support/propagated-user-env-packages

    install -Dm644 assets/icon/terminal.png $out/share/icons/hicolor/128x128/apps/org.wezfurlong.wezterm.png
    install -Dm644 assets/wezterm.desktop $out/share/applications/org.wezfurlong.wezterm.desktop
    install -Dm644 assets/wezterm.appdata.xml $out/share/metainfo/org.wezfurlong.wezterm.appdata.xml

    install -Dm644 assets/shell-integration/wezterm.sh -t $out/etc/profile.d
    installShellCompletion --cmd wezterm \
      --bash assets/shell-completion/bash \
      --fish assets/shell-completion/fish \
      --zsh assets/shell-completion/zsh

    install -Dm644 assets/wezterm-nautilus.py -t $out/share/nautilus-python/extensions
  '';

  preFixup = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
    patchelf \
      --add-needed "${pkgs.libGL}/lib/libEGL.so.1" \
      --add-needed "${pkgs.vulkan-loader}/lib/libvulkan.so.1" \
      $out/bin/wezterm-gui
  '' + pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
    mkdir -p "$out/Applications"
    OUT_APP="$out/Applications/WezTerm.app"
    cp -r assets/macos/WezTerm.app "$OUT_APP"
    rm $OUT_APP/*.dylib
    cp -r assets/shell-integration/* "$OUT_APP"
    ln -s $out/bin/{wezterm,wezterm-mux-server,wezterm-gui,strip-ansi-escapes} "$OUT_APP"
  '';

  passthru = {
    tests = {
      all-terminfo = pkgs.nixosTests.allTerminfo;
      terminal-emulators = pkgs.nixosTests.terminal-emulators.wezterm;
    };
    terminfo = pkgs.runCommand "wezterm-terminfo"
      {
        nativeBuildInputs = [ pkgs.ncurses ];
      } ''
      mkdir -p $out/share/terminfo $out/nix-support
      tic -x -o $out/share/terminfo ${src}/termwiz/data/wezterm.terminfo
    '';
  };

  meta = with pkgs.lib; {
    description = "GPU-accelerated cross-platform terminal emulator and multiplexer written by @wez and implemented in Rust";
    homepage = "https://wezfurlong.org/wezterm";
    license = licenses.mit;
    mainProgram = "wezterm";
    maintainers = with maintainers; [ SuperSandro2000 mimame ];
  };
}
