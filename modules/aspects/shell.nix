# modules/aspects/shell.nix — full desktop shell bundle
{ garden, ... }:
{
  garden.shell = {
    includes = [
      garden.palette
      garden.terminal
      garden.toolkit
      garden.daemon
      garden.ctl
      garden.tui
      garden.observability
    ];

    nixos = { pkgs, ... }: {
      # Ensure niri is available system-wide (compositor).
    };

    homeManager = { config, lib, pkgs, ... }: {
      # Deploy QML shell files to ~/.config/quickshell/garden/
      xdg.configFile."quickshell/garden" = {
        source = ../../_qml;
        recursive = true;
      };

      # Deploy settings.json as mutable copy so modes can be edited at runtime.
      home.activation.gardenSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        install -Dm644 ${../../_config/settings.json} \
          ${config.xdg.configHome}/garden/settings.json
      '';

      # NOTE: Niri config is managed by the consumer (e.g. fern) via
      # programs.niri.settings. The consumer is responsible for wiring
      # keybinds to garden overlay IPC (toggleLauncher, toggleSwitcher).
    };
  };
}
