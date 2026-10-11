let
  sha256 = "c610461834f130d01b2bc158b83c2eabe6e48077ba1475349e0af91323cd1d7a";
  artifact = ./bypass_paywalls_clean-4.4.6.6.xpi;
in
{
  version = "4.4.6.6";
  addonId = "magnolia@12.34";
  inherit sha256;
  # Preserve the publisher's signed bytes; never unpack/repack this source.
  src = assert builtins.hashFile "sha256" artifact == sha256; artifact;
}
