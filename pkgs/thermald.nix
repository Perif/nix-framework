{ thermald, fetchFromGitHub }:

# Targeted update; keep the rest of the stable Nixpkgs closure unchanged.
thermald.overrideAttrs (old: rec {
  version = "2.5.13";
  src = fetchFromGitHub {
    owner = "intel";
    repo = "thermal_daemon";
    tag = "v${version}";
    hash = "sha256-SFVQQzWOG8vdxiWV9lFnz9niVJB5QaclWGENzGgqZCk=";
  };
  # Documentation became opt-in in 2.5.12. Retain the devdoc output.
  configureFlags = old.configureFlags ++ [ "--enable-doc" ];
  meta = old.meta // {
    changelog = "https://github.com/intel/thermal_daemon/blob/v${version}/README.txt";
  };
})
