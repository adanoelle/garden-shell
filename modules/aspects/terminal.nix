# modules/aspects/terminal.nix — terminal stack (kitty, fish, kakoune)
{ garden, ... }:
{
  garden.terminal = {
    includes = [ garden.palette ];

    nixos = { pkgs, ... }: {
      # S1 stub: system-level terminal config
    };

    homeManager = { pkgs, ... }: {
      # S1 stub: kitty + fish + kakoune config
    };
  };
}
