{
  ghidra-bin,
  fetchurl,
  unzip,
}:
# REA 6.4 accepts the 12.1 release line and verifies its bridge on 12.1.4.
# Reuse Nixpkgs' native-library fixups and JDK launcher, with the official build.
ghidra-bin.overrideAttrs (old: {
  version = "12.1.4";
  versiondate = "20260921";
  src = fetchurl {
    url = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip";
    hash = "sha256-3axJ+QPanVusgz5cx5OVCYucM8/TJ5vl8xvQA4fS1Ns=";
  };
  nativeBuildInputs = old.nativeBuildInputs ++ [ unzip ];
  meta = old.meta // {
    platforms = [ "x86_64-linux" ];
  };
})
