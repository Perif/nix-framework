{ lib, settings, ... }:

let
  uBlockOriginLiteId = "ddkjiahejlhfcafbddmgiahcphecmpfh";

  # Brave policies are isolated from the shared Chromium policy file so
  # ungoogled Chromium does not report Brave-only or Google-service keys as
  # unknown. Keep the Chrome Web Store extension and Safe Browsing controls
  # here: ungoogled Chromium deliberately removes those Google integrations.
  bravePrivacyPolicies = {
    BraveAIChatEnabled = false;
    BraveNewsDisabled = true;
    BraveP3AEnabled = false;
    BraveRewardsDisabled = true;
    BraveStatsPingEnabled = false;
    BraveTalkDisabled = true;
    BraveVPNDisabled = true;
    BraveWalletDisabled = true;
    BraveWebDiscoveryEnabled = false;
    ChromeVariations = 1;

    ExtensionInstallForcelist = [ uBlockOriginLiteId ];

    DisableSafeBrowsingProceedAnyway = true;
    SafeBrowsingEnabled = true;
    SafeBrowsingExtendedReportingEnabled = false;
    SafeBrowsingProtectionLevel = 1;
    SafeBrowsingSurveysEnabled = false;

    # Managed uBOL settings retain the maintained default lists, add URL
    # tracking-parameter protection, and use the current Optimal mode.
    "3rdparty".extensions.${uBlockOriginLiteId} = {
      defaultFiltering = "optimal";
      disableFirstRunPage = true;
      popupBlockMode = true;
      rulesets = [
        "+default"
        "+adguard-spyware-url"
      ];
      showBlockedCount = true;
      strictBlockMode = true;
    };

    # The upstream Tor Browser is installed separately. Brave's private Tor
    # window has a different fingerprint and should not be treated as a
    # substitute for it.
    TorDisabled = true;
  };
in
lib.mkIf settings.features.extraBrowsers {
  # NixOS writes these shared managed policies for ungoogled Chromium and
  # Brave. The browser UI will therefore truthfully say that it is managed by
  # an organization.
  programs.chromium = {
    enable = true;
    homepageLocation = "about:blank";
    defaultSearchProviderEnabled = true;
    defaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";

    extraOpts = {
      # Avoid background requests, prediction, search suggestions and reports
      # that are not required for rendering the page the user requested.
      AlternateErrorPagesEnabled = false;
      BackgroundModeEnabled = false;
      BrowserNetworkTimeQueriesEnabled = false;
      BrowserSignin = 0;
      DomainReliabilityAllowed = false;
      FeedbackSurveysEnabled = false;
      MetricsReportingEnabled = false;
      NetworkPredictionOptions = 2;
      PromotionsEnabled = false;
      SearchSuggestEnabled = false;
      SpellcheckServiceEnabled = false;
      SyncDisabled = true;
      UrlKeyedAnonymizedDataCollectionEnabled = false;
      UserFeedbackAllowed = false;

      # Keep all Chromium-family lookups on systemd-resolved. That preserves
      # local Blocky filtering and more-specific UniFi/WireGuard split-DNS
      # routes.
      BuiltInDnsClientEnabled = false;
      DnsOverHttpsMode = "off";

      # Remove ad-personalization surfaces and unrequested browser AI. Local
      # development uses the explicit Ollama/llama.cpp endpoints instead.
      BuiltInAIAPIsEnabled = false;
      DevToolsGenAiSettings = 2;
      GenAILocalFoundationalModelSettings = 1;
      PrivacySandboxAdMeasurementEnabled = false;
      PrivacySandboxAdTopicsEnabled = false;
      PrivacySandboxPromptEnabled = false;
      PrivacySandboxSiteEnabledAdsEnabled = false;

      # Block the most common cross-site state while leaving first-party
      # cookies, JavaScript and ordinary site permissions functional.
      BlockThirdPartyCookies = true;
      EnableDoNotTrack = true;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;

      # Keep WebRTC calls usable without advertising private interface
      # addresses to remote peers.
      WebRtcIPHandling = "default_public_interface_only";
    };
  };

  environment.etc."brave/policies/managed/brave-privacy.json".text =
    builtins.toJSON bravePrivacyPolicies;
}
