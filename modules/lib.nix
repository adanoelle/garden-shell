# modules/lib.nix — export eval-time palette colors for Nix consumers
{ ... }:
{
  flake.lib.palette =
    let
      raw = builtins.fromTOML (builtins.readFile ../_config/palettes.toml);
      active = raw.palettes.${raw.active};
    in
    {
      activeName = raw.active;
      inherit (active) name subtitle icon colors;
      all = raw.palettes;
    };
}
