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
        # Relative path from ~/.config/kitty/ to ~/.config/garden/themes/.
        programs.kitty.extraConfig = ''
          include ../garden/themes/kitty/garden-theme.conf
        '';

        # Fish: source garden themes and symlink tool-specific theme files
        # on shell init. Universal variables propagate to all sessions, but
        # this ensures new sessions start with the current palette.
        programs.fish.interactiveShellInit = ''
          # Fish syntax colors
          if test -f ${themesDir}/fish/garden-theme.fish
            source ${themesDir}/fish/garden-theme.fish
          end

          # fzf colors
          if test -f ${themesDir}/fzf/garden-theme.fish
            source ${themesDir}/fzf/garden-theme.fish
          end

          # bat: symlink tmTheme and rebuild cache when theme changes.
          # Compare mtime so a palette switch triggers a cache rebuild.
          if test -f ${themesDir}/bat/garden.tmTheme
            mkdir -p ~/.config/bat/themes
            ln -sf ${themesDir}/bat/garden.tmTheme ~/.config/bat/themes/garden.tmTheme
            if not test -f ~/.cache/bat/themes.bin
              or test ${themesDir}/bat/garden.tmTheme -nt ~/.cache/bat/themes.bin
              bat cache --build 2>/dev/null
            end
          end

          # btop: symlink theme into btop's discovery directory
          if test -f ${themesDir}/btop/garden.theme
            mkdir -p ~/.config/btop/themes
            ln -sf ${themesDir}/btop/garden.theme ~/.config/btop/themes/garden.theme
          end

          # yazi: symlink as yazi's theme.toml (merged over preset)
          if test -f ${themesDir}/yazi/garden-theme.toml
            ln -sf ${themesDir}/yazi/garden-theme.toml ${config.xdg.configHome}/yazi/theme.toml
          end

        '';

        # Kakoune: source garden theme on editor startup.
        programs.kakoune.extraConfig = ''
          try %{ source ${themesDir}/kak/garden.kak }
        '';

        # bat: use garden tmTheme for syntax highlighting.
        home.sessionVariables.BAT_THEME = "garden";

        # lazygit: merge garden theme overlay with base lazygit config.
        # LG_CONFIG_FILE accepts a comma-separated list; the second
        # file's values override the first.
        home.sessionVariables.LG_CONFIG_FILE =
          "${config.xdg.configHome}/lazygit/config.yml,${themesDir}/lazygit/garden.yml";

        # zathura: include garden theme from the themes directory.
        programs.zathura.extraConfig = ''
          include ${themesDir}/zathura/gardenrc
        '';
      };
  };
}
