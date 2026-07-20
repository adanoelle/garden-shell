# modules/aspects/toolkit.nix — CLI tool suite
{ garden, self, ... }:
{
  garden.toolkit = {
    includes = [ garden.palette ];

    nixos = { pkgs, ... }: {
      # S1 stub: system-level CLI tools
    };

    homeManager = { pkgs, ... }: {
      home.packages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.garden-themes
      ];
    };
  };
}
