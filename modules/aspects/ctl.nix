# modules/aspects/ctl.nix — garden-ctl CLI tool
{ garden, ... }:
{
  garden.ctl = {
    includes = [ garden.daemon ];

    homeManager = { pkgs, ... }: {
      # S1 stub: garden-ctl binary
    };
  };
}
