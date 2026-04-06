# modules/aspects/observability.nix — SSH monitoring + health checks
{ garden, ... }:
{
  garden.observability = {
    includes = [ garden.daemon ];

    nixos = { pkgs, ... }: {
      # S1 stub: SSH ControlMaster config
    };

    homeManager = { ... }: {
      # S1 stub: socket directory
    };
  };
}
