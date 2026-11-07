{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libxcb,
  libxkbcommon,
  vulkan-loader,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-app";
  version = "0.1.13";

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${finalAttrs.version}/herdr-app-linux-x86_64.tar.gz";
    hash = "sha256-d7C+cqRsoUuzZzZaBBZGQfkUs6aXErrDkdOcVqlZvvQ=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libxkbcommon
    vulkan-loader
    libxcb
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 herdr-app "$out/bin/herdr-app"
    install -Dm644 herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
    install -Dm644 LICENSE "$out/share/licenses/${finalAttrs.pname}/LICENSE"
    install -Dm644 THIRD-PARTY-NOTICES "$out/share/doc/${finalAttrs.pname}/THIRD-PARTY-NOTICES"

    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/herdr-app.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=Herdr
    Comment=Terminals and coding agents that keep running
    Exec=herdr-app
    Icon=herdr-app
    Terminal=false
    Categories=Development;
    StartupWMClass=herdr-app
    EOF

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/herdr-app" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ vulkan-loader ]}
  '';

  meta = {
    description = "Herdr desktop application for terminals and coding agents";
    homepage = "https://herdr.dev/";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = [ "x86_64-linux" ];
  };
})
