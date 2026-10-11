{ pkgs }:
let
  linux = pkgs.stdenv.hostPlatform.isLinux;
  rea = pkgs.callPackage (if linux then ../pkgs/rea-with-ghidra.nix else ../pkgs/rea.nix) { };
  ollaya = pkgs.callPackage ../pkgs/ollaya.nix { };
in
pkgs.runCommand (if linux then "rea-ghidra-mcp-tests" else "rea-mcp-discovery-tests")
  {
    nativeBuildInputs = [
      pkgs.python3
    ] ++ pkgs.lib.optional linux pkgs.stdenv.cc;
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${rea}/bin/rea --help > /dev/null
    ${pkgs.lib.optionalString linux ''
      # A known local fixture, analyzed statically and never executed by REA.
      printf 'int main(void) { return 42; }\n' > fixture.c
      cc -g -O0 fixture.c -o fixture
      if ! ${rea}/bin/rea doctor --provider ghidra --format json > doctor.json; then
        cat doctor.json
        exit 1
      fi
    ''}
    python3 ${./test_rea_mcp.py} --rea ${rea}/bin/rea \
      ${pkgs.lib.optionalString linux ''--target "$PWD/fixture" --ollaya ${ollaya}/bin/ollaya''}
    touch "$out"
  ''
