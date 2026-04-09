# modules/aspects/palette.nix — foundation palette aspect
{ garden, ... }:
{
  garden.palette = {
    homeManager = { config, lib, pkgs, ... }: {
      # Deploy palettes.toml as a mutable copy so `garden-themes apply --name`
      # can write back the updated `active` field.
      home.activation.gardenPalettes = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        install -Dm644 ${../../_config/palettes.toml} \
          ${config.xdg.configHome}/garden/palettes.toml
      '';
    };
  };
}
