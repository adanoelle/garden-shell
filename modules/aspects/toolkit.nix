# modules/aspects/toolkit.nix — CLI tool suite
{ garden, ... }:
{
  garden.toolkit = {
    includes = [ garden.palette ];

    nixos = { pkgs, ... }: {
      # S1 stub: system-level CLI tools
    };

    homeManager = { ... }: {
      # S1 stub: user-level CLI tools
    };
  };
}
