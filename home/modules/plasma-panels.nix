{ ... }:

{
  programs.plasma = {
    enable = true;

    # Keep other Plasma state user-managed; this module owns only this panel.
    overrideConfig = false;

    panels = [
      {
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          {
            name = "org.kde.plasma.icontasks";
            config.General = {
              groupingStrategy = 0;
              launchers = "preferred://filemanager,preferred://browser,applications:wine-Programs-1Password-1Password 4.desktop,applications:com.mitchellh.ghostty.desktop";
            };
          }
          {
            # Plasma Manager's restart detection expects an attribute set here.
            name = "org.kde.plasma.systemmonitor";
            config = { };
          }
          "org.kde.plasma.marginsseparator"
          {
            name = "org.kde.plasma.systemmonitor.cpu";
            config = {
              Appearance = { chartFace = "org.kde.ksysguard.linechart"; title = "Total CPU Use"; };
              SensorColors = { "cpu/all/averageTemperature" = "233,81,61"; "cpu/all/usage" = "170,0,127"; };
              Sensors = { highPrioritySensorIds = "[\"cpu/all/usage\",\"cpu/all/averageTemperature\"]"; lowPrioritySensorIds = "[\"cpu/all/cpuCount\",\"cpu/all/coreCount\"]"; totalSensors = "[\"cpu/all/usage\"]"; };
            };
          }
          {
            name = "org.kde.plasma.systemmonitor.memory";
            config = {
              Appearance = { chartFace = "org.kde.ksysguard.linechart"; title = "Memory Usage"; };
              SensorColors."memory/physical/used" = "61,174,233";
              Sensors = { highPrioritySensorIds = "[\"memory/physical/used\"]"; lowPrioritySensorIds = "[\"memory/physical/total\"]"; totalSensors = "[\"memory/physical/usedPercent\"]"; };
            };
          }
          {
            name = "org.kde.plasma.systemmonitor.net";
            config = {
              Appearance = { chartFace = "org.kde.ksysguard.linechart"; title = "Network Speed"; };
              SensorColors = { "network/all/download" = "61,174,233"; "network/all/upload" = "233,120,61"; };
              Sensors.highPrioritySensorIds = "[\"network/all/download\",\"network/all/upload\"]";
            };
          }
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];
  };
}
