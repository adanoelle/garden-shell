# modules/aspects/toolkit.nix — CLI tool suite
{ garden, ... }:
{
  garden.toolkit = {
    includes = [ garden.palette ];

    nixos = { pkgs, ... }: {
      # S1 stub: system-level CLI tools
    };

    homeManager = { ... }: {
      # TODO: add garden-themes to home.packages once overlay is defined
    };
  };
}
