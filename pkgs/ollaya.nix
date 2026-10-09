{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  zstd,
}:

stdenvNoCC.mkDerivation rec {
  pname = "ollaya";
  version = "0.7.5";

  # Official CPU archive, pinned against the release's sha256sum.txt. Keep its
  # llama.cpp libraries: Ollaya checks their ABI and cannot use nixpkgs' build.
  src = fetchurl {
    url = "https://github.com/ollaya-dev/ollaya/releases/download/v${version}/ollaya-linux-amd64.tar.zst";
    hash = "sha256-nipoqdB2LIGelM/DD4qK2jecamPxxm2/amGC93yjI1M=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    zstd
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a bin lib share "$out/"
    # This laptop uses the CPU backend. The separate CUDA runner needs an
    # uninstalled CUDA pack and is deliberately omitted from this package.
    rm "$out/lib/ollaya/ollaya-cuda-runner"
    runHook postInstall
  '';

  # Runs after ELF fixups, on a Linux build host; requires no models/network.
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/ollaya-check"
    mkdir -p "$HOME"
    "$out/bin/ollaya" --help > /dev/null
    "$out/bin/ollaya" llama-devices > devices.json
    grep -q '"cpu"' devices.json
    runHook postInstallCheck
  '';

  meta = {
    description = "Local decision-model runtime (official CPU build)";
    homepage = "https://ollaya.dev";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ollaya";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
