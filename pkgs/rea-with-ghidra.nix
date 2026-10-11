{
  lib,
  callPackage,
  symlinkJoin,
  makeWrapper,
  jdk21,
}:
let
  rea = callPackage ./rea.nix { };
  ghidra = callPackage ./rea-ghidra.nix { };
in
symlinkJoin {
  name = "rea-${rea.version}";
  paths = [ rea ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    for command in rea rea-agents; do
      wrapProgram "$out/bin/$command" \
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
