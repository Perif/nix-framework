{
  lib,
  pkgs,
  settings,
  ...
}:

let
  packageFile = settings.qbz.packageFile;
  validPackageFile = builtins.isPath packageFile && builtins.pathExists packageFile;
in
{
  assertions = [
    {
      assertion = validPackageFile;
      message = "features.qbz requires qbz.packageFile to name an existing user-supplied Nix package recipe; upstream QBZ distribution is no longer available.";
    }
  ];

  home.packages = lib.optional validPackageFile (pkgs.callPackage packageFile { });
}
