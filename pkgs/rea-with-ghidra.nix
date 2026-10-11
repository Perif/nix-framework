{
  lib,
  callPackage,
  symlinkJoin,
  makeWrapper,
  jdk21,
  procps,
}:
let
  rea = callPackage ./rea.nix { };
  ghidra = callPackage ./rea-ghidra.nix { };
in
symlinkJoin {
  name = "rea-${rea.version}";
  paths = [ rea ];
  nativeBuildInputs = [ makeWrapper ];
  # REA validates process ownership with procps before it launches the JVM.
  # Supply it for GUI/MCP clients as well as interactive shells.
  postBuild = ''
    for command in rea rea-agents; do
      wrapProgram "$out/bin/$command" \
        --prefix PATH : ${lib.makeBinPath [ procps ]} \
        --set REA_ANALYSIS_PROVIDER ghidra \
        --set GHIDRA_INSTALL_DIR ${ghidra}/lib/ghidra \
        --set JAVA_HOME ${jdk21.home} \
        --set-default REA_MCP_INPUT_SCHEMA_PROFILE compact
    done
  '';
  passthru = {
    inherit ghidra;
    unwrapped = rea;
  };
  meta = rea.meta // {
    description = "REA with its supported Ghidra backend and JDK";
    mainProgram = "rea";
    # The official Ghidra archive includes Linux x86-64 native decompilers;
    # Darwin natives require a separate source build outside this package.
    platforms = [ "x86_64-linux" ];
  };
}
