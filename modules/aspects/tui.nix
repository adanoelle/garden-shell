# modules/aspects/tui.nix — garden terminal UI
{ garden, ... }:
{
  garden.tui = {
    includes = [ garden.ctl garden.palette ];

    homeManager = { pkgs, ... }: {
      # S1 stub: garden-tui binary
    };
  };
}
