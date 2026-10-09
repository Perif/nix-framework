{ pkgs, settings, ... }:

let
  addons = pkgs.nur.repos.rycee.firefox-addons;
  # Preserve the publisher's signed artifact locally: its rolling upload list
  # prunes old releases. Shared metadata verifies the exact source bytes.
  bypassPaywallsSource = import ../../pkgs/bypass-paywalls-clean/source.nix;
  bypassPaywallsClean = addons.bypass-paywalls-clean.overrideAttrs {
    name = "bypass-paywalls-clean-${bypassPaywallsSource.version}";
    inherit (bypassPaywallsSource) version src;
  };
in
{
  programs.firefox = {
    enable = true;

    # Enterprise policies cover browser-wide privacy controls that are
    # more stable and auditable than duplicating them as profile prefs.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = true;
      DisableFormHistory = true;
      DisablePasswordReveal = true;
      SearchSuggestEnabled = false;
      StartDownloadsInTempDirectory = true;

      # Fail closed on certificate and Safe Browsing interstitials instead of
      # offering a click-through around a known security failure.
      DisableSecurityBypass = {
        InvalidCertificate = true;
        SafeBrowsing = true;
      };

      # Disable Firefox's built-in / experimental AI surfaces.
      GenerativeAI = {
        Enabled = false;
        Locked = true;
      };

      # Strict tracking protection, including known fingerprinters and
      # cryptominers.
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Category = "strict";
        Cryptomining = true;
        Fingerprinting = true;
        SuspectedFingerprinting = true;
        EmailTracking = true;
      };

      # HTTPS-first / HTTPS-only behavior.
      HttpsOnlyMode = "enabled";

      # Use Blocky's explicitly unfiltered upstream directly over HTTPS/443.
      # Bypassing the local list gives Firefox a recovery path for DNS false
      # positives. This remains unlocked for VPN/private-DNS overrides.
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = settings.dns.dohUrl;
        Locked = false;
        Fallback = false;
        ExcludedDomains = [
          "localhost"
          "local"
          "home.arpa"
        ];
      };

      # uMatrix is archived. Enable uBlock Origin's maintained advanced
      # dynamic-filtering UI without overwriting the user's per-site rules.
      "3rdparty".Extensions."uBlock0@raymondhill.net".userSettings = [
        [
          "advancedUserEnabled"
          "true"
        ]
      ];

      # Do not let websites silently use location, camera, microphone,
      # notifications or autoplay. They must be explicitly permitted.
      Permissions = {
        Location = {
          BlockNewRequests = true;
          Locked = false;
        };
        Notifications = {
          BlockNewRequests = true;
          Locked = false;
        };
        Camera = {
          BlockNewRequests = true;
          Locked = false;
        };
        Microphone = {
          BlockNewRequests = true;
          Locked = false;
        };
        Autoplay = {
          Default = "block-audio-video";
          Locked = false;
        };
      };

      # Disable browser-sponsored / recommendation messaging.
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
        FirefoxLabs = false;
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;
      name = "default";

      # Automatically approve declaratively installed extensions.
      settings = {
        "extensions.autoDisableScopes" = 0;

        ##############################################################
        # Tracking / storage isolation
        ##############################################################

        # Total Cookie Protection / partition cross-site storage.
        "network.cookie.cookieBehavior" = 5;
        "privacy.partition.network_state" = true;
        "privacy.userContext.enabled" = true;
        "privacy.userContext.ui.enabled" = true;

        # Global Privacy Control / Do Not Track.
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled" = true;

        ##############################################################
        # Fingerprinting resistance
        ##############################################################

        # Strong anti-fingerprinting. This intentionally trades some
        # usability/site compatibility for privacy.
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.letterboxing" = true;

        # Reduce canvas fingerprinting surface.
        "privacy.fingerprintingProtection" = true;
        "privacy.fingerprintingProtection.pbmode" = true;

        ##############################################################
        # WebRTC / local network leakage
        ##############################################################

        # Keep WebRTC functional but prevent host-address ICE candidates
        # from exposing local addresses to remote sites.
        "media.peerconnection.ice.no_host" = true;
        "media.peerconnection.ice.default_address_only" = true;

        ##############################################################
        # Referrer / URL privacy
        ##############################################################

        "network.http.referer.XOriginTrimmingPolicy" = 2;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;

        ##############################################################
        # DNS / speculative connections / prefetch
        ##############################################################

        "network.prefetch-next" = false;
        "network.dns.disablePrefetch" = true;
        "network.predictor.enabled" = false;
        "network.predictor.enable-prefetch" = false;
        "browser.urlbar.speculativeConnect.enabled" = false;
        "browser.send_pings" = false;
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.searches" = false;

        ##############################################################
        # Telemetry / experiments / sponsored content
        ##############################################################

        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;

        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;

        ##############################################################
        # Mozilla / browser features not needed for this profile
        ##############################################################

        "browser.pocket.enabled" = false;
        "extensions.pocket.enabled" = false;
        "browser.shopping.experience2023.enabled" = false;

        # Disable Firefox Suggest data collection / remote suggestions.
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.urlbar.quicksuggest.dataCollection.enabled" = false;

        # Do not retain addresses or payment-card data in the browser profile.
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;

        # Disable geolocation provider access by default.
        "geo.enabled" = false;

        ##############################################################
        # Security
        ##############################################################

        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_pbm" = true;

        # Keep Safe Browsing enabled. Disabling it is not a privacy win
        # sufficient to justify the security regression.
        "browser.safebrowsing.malware.enabled" = true;
        "browser.safebrowsing.phishing.enabled" = true;
        "browser.safebrowsing.downloads.enabled" = true;

        # Make insecure transport visible and reject HTTP subresources in an
        # otherwise HTTPS page, including passive images and media.
        "security.insecure_connection_text.enabled" = true;
        "security.insecure_connection_text.pbmode.enabled" = true;
        "security.mixed_content.block_active_content" = true;
        "security.mixed_content.block_display_content" = true;

        # Block rather than silently granting persistent site permissions.
        "permissions.default.camera" = 2;
        "permissions.default.microphone" = 2;
        "permissions.default.geo" = 2;
        "permissions.default.desktop-notification" = 2;
      };

      extensions = {
        force = true;

        packages = with addons; [
          ublock-origin
          noscript
          onetab
          privacy-badger
          enhancer-for-youtube
          decentraleyes
          bypassPaywallsClean
          skip-redirect
          multi-account-containers
        ];

      };

      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
      };
    };
  };
}
