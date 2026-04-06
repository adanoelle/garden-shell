# modules/aspects/daemon.nix — garden infrastructure daemon
{ garden, ... }:
{
  garden.daemon = {
    nixos = { pkgs, ... }: {
      # S1 stub: systemd user service for garden-daemon
    };

    homeManager = { ... }: {
      # S1 stub: daemon config file
    };
  };
}
