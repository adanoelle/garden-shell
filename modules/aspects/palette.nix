# modules/aspects/palette.nix — foundation palette aspect
{ garden, ... }:
{
  garden.palette = {
    homeManager = { pkgs, ... }: {
      xdg.configFile."garden/palettes.json".source = ../../_config/palettes.json;
    };
  };
}
