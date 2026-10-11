{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  autoPatchelfHook,
}:
buildNpmPackage rec {
  pname = "rea-agents";
  version = "6.4.0";

  # Official npm release includes compiled JS and the analysis bridges. Its
  # dependency lock comes from the exact gitHead published with that release.
  src = fetchurl {
    url = "https://registry.npmjs.org/rea-agents/-/rea-agents-${version}.tgz";
    hash = "sha256-WesWBLjbdfUi1Kl1w2zmtKKtRl5DutFl+aj3KDkdubg=";
  };
  postPatch = ''
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/morluto/rea/a56f7bb668ab23fec8d33f7af353ac7ed2fe1895/package-lock.json";
        hash = "sha256-tlXiEYl71yAy72kmG+hxDlA3se3neBBsj+9zAwetAFk=";
      }
    } package-lock.json
  '';
  npmDepsHash = "sha256-ghZW1p/vXt67E31LsvU+oZLOYvYz0cNc2qfvSEZYT9Q=";
  npmDepsFetcherVersion = 2;
  npmInstallFlags = [ "--omit=dev" ];
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  dontNpmPrune = true;

  # node-pty ships platform-specific native components in its npm dependency.
  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;

  meta = {
    description = "Reverse Engineer Anything CLI and MCP analysis tools";
    homepage = "https://github.com/morluto/rea";
    license = lib.licenses.mit;
    mainProgram = "rea";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}
