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
      garden.observability
    ];

    nixos = { pkgs, ... }: {
      # S1 stub: niri + quickshell
    };

    homeManager = { pkgs, ... }: {
      # S1 stub: QML shell + niri config + settings
    };
  };
}
