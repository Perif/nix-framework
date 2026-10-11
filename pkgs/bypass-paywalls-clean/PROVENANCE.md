# Bypass Paywalls Clean source

`bypass_paywalls_clean-4.4.6.6.xpi` is an unmodified publisher artifact downloaded
on 2026-10-09. It is kept here because the publisher's rolling upload repository
removed previously pinned releases 4.4.5.3 and 4.4.5.6, breaking fresh builds.

- Publisher project: <https://gitflic.ru/project/magnolia1234/bypass-paywalls-firefox-clean>
- Download: <https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-4.4.6.6.xpi>
- Publisher hashes: <https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=release-hashes.txt>
- Upload repository revision observed at download: `b730c338030c7feb3180c9c3aa5353de943ccace`
- Size: 323,421 bytes
- SHA-256: `c610461834f130d01b2bc158b83c2eabe6e48077ba1475349e0af91323cd1d7a`
- Manifest version: `4.4.6.6`; extension ID: `magnolia@12.34`
- License: MIT, copyright magnolia1234; [LICENSE](LICENSE) is copied verbatim
  from the archive, which also retains its original license notices.

The downloaded hash matched the publisher's release-hashes.txt. The archive
contains Mozilla signing metadata (`META-INF/mozilla.rsa`, `mozilla.sf`,
`manifest.mf`, `cose.manifest`, and `cose.sig`). The integrity check verifies the
archive and metadata; it does not independently validate Mozilla's signature
chain. Firefox retains its normal signature enforcement.

For an update, download the standard signed XPI directly from the publisher,
compare its SHA-256 with the publisher's hashes, inspect its manifest ID/version
and license/signing files, and retain the bytes unchanged. Update `source.nix`,
this provenance record and the extracted license together. Run the
`bypass-paywalls-clean` flake check and the full Linux build before merging.
Do not replace this artifact with an unsigned source ZIP or disable Firefox's
signature checks.
