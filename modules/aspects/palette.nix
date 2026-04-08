# modules/aspects/palette.nix — foundation palette aspect
{ garden, lib, ... }:
{
  garden.palette = {
    homeManager = { config, pkgs, ... }: {
      # Deploy palettes.toml as a mutable copy so `garden-themes apply --name`
      # can write back the updated `active` field.
      home.activation.gardenPalettes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        install -Dm644 ${../../_config/palettes.toml} \
          ${config.xdg.configHome}/garden/palettes.toml
      '';
    };
  };
}
