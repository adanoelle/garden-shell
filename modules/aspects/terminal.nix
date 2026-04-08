# modules/aspects/terminal.nix — terminal stack (kitty, fish, kakoune)
{ garden, ... }:
{
  garden.terminal = {
    includes = [ garden.palette ];

    nixos = { pkgs, ... }: {
      # S1 stub: system-level terminal config
    };

    homeManager = { config, pkgs, ... }:
      let
        themesDir = "${config.xdg.configHome}/garden/themes";
      in
      {
        # Kitty: include garden theme from mutable themes dir so SIGUSR1
        # config reload picks up palette changes across all instances.
        # globinclude silently skips missing files (safe before first apply).
        programs.kitty.extraConfig = ''
          globinclude ${themesDir}/kitty/garden-theme.conf
        '';

        # Fish: source garden theme on shell init (universal variables
        # propagate to all sessions, but this ensures new sessions start
        # with the current palette).
        programs.fish.interactiveShellInit = ''
          if test -f ${themesDir}/fish/garden-theme.fish
            source ${themesDir}/fish/garden-theme.fish
          end
        '';

        # Kakoune: source garden theme on editor startup.
        programs.kakoune.extraConfig = ''
          try %{ source ${themesDir}/kak/garden.kak }
        '';
      };
  };
}
