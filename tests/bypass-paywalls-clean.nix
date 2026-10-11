{ pkgs }:
let
  source = import ../pkgs/bypass-paywalls-clean/source.nix;
in
pkgs.runCommand "bypass-paywalls-clean-integrity"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    inherit (source) src version addonId sha256;
    licenseFile = ../pkgs/bypass-paywalls-clean/LICENSE;
  }
  ''
    python3 - <<'PY'
    import hashlib
    import json
    import os
    from pathlib import Path
    import zipfile

    source = Path(os.environ["src"])
    assert hashlib.sha256(source.read_bytes()).hexdigest() == os.environ["sha256"]
    with zipfile.ZipFile(source) as archive:
        assert archive.testzip() is None, "XPI contains a corrupt entry"
        manifest = json.loads(archive.read("manifest.json"))
        assert manifest["version"] == os.environ["version"]
        assert manifest["browser_specific_settings"]["gecko"]["id"] == os.environ["addonId"]
        for name in ("mozilla.rsa", "mozilla.sf", "manifest.mf", "cose.manifest", "cose.sig"):
            assert archive.read("META-INF/" + name), "Missing signing metadata: " + name
        assert archive.read("LICENSE") == Path(os.environ["licenseFile"]).read_bytes()
        assert b"MIT License" in archive.read("LICENSE")
    print("Publisher hash, archive integrity, manifest, signing metadata and license verified.")
    PY
    touch "$out"
  ''
