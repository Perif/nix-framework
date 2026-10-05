{ pkgs }:

let
  evaluate =
    packageFile:
    import ../home/modules/qbz.nix {
      inherit pkgs;
      inherit (pkgs) lib;
      settings.qbz.packageFile = packageFile;
    };
  accepted = module: builtins.all (check: check.assertion) module.assertions;
  missing = evaluate null;
  nonexistent = evaluate ./fixtures/nonexistent-qbz-package.nix;
  stringPath = evaluate (toString ./fixtures/qbz-package.nix);
  supplied = evaluate ./fixtures/qbz-package.nix;
in
assert !accepted missing && missing.home.packages == [ ];
assert !accepted nonexistent && nonexistent.home.packages == [ ];
assert !accepted stringPath && stringPath.home.packages == [ ];
assert accepted supplied;
assert map (package: package.drvPath) supplied.home.packages == [ pkgs.hello.drvPath ];
true
