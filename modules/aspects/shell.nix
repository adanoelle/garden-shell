# modules/aspects/shell.nix — full desktop shell bundle
{ garden, ... }:
{
  garden.shell = {
    includes = [
      garden.palette
      garden.terminal
      garden.toolkit
      garden.daemon
      garden.ctl
      garden.tui
      garden.observability
    ];

    nixos = { pkgs, ... }: {
      # Ensure niri is available system-wide (compositor).
    };

    homeManager = { config, lib, pkgs, ... }: {
      # Screenshot flow runtime deps (IPC `screenshot <mode>`):
      # grim/slurp capture, satty edit action, wl-clipboard copy.
      home.packages = with pkgs; [ grim slurp satty wl-clipboard ];

      # Deploy QML shell files to ~/.config/quickshell/garden/
      xdg.configFile."quickshell/garden" = {
        source = ../../_qml;
        recursive = true;
      };

      # Deploy settings.json as mutable copy so modes can be edited at runtime.
      # Only seed if the file does not already exist — this preserves
      # runtime edits across `nixos-rebuild switch` / `home-manager switch`.
      home.activation.gardenSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${config.xdg.configHome}/garden/settings.json" ]; then
          install -Dm644 ${../../_config/settings.json} \
            ${config.xdg.configHome}/garden/settings.json
        fi
      '';

      # Restart the running shell when its QML changes. Quickshell is
      # started once by the compositor (niri spawn-at-startup) and does
      # not notice home-manager re-pointing the per-file symlinks, so a
      # switch that ships new QML otherwise leaves the old shell running
      # until the next login. The QML source's store path is the change
      # key: recorded in $XDG_STATE_HOME/garden/qml-source and compared
      # on every activation. The relaunch goes through `niri msg action
      # spawn` so the new shell is a child of the session; outside a
      # niri session (NIRI_SOCKET unset, e.g. a switch over ssh) it only
      # prints how to restart. Never fails the activation.
      home.activation.gardenShellRestart =
        let
          qmlSource = "${../../_qml}";
          stateFile = "${config.xdg.stateHome}/garden/qml-source";
          pgrep = "${pkgs.procps}/bin/pgrep";
        in
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          garden_restart() {
            local prev="" pid argv0 niri_bin
            [ -r "${stateFile}" ] && prev=$(cat "${stateFile}")
            [ "$prev" = "${qmlSource}" ] && return 0
            run mkdir -p "$(dirname "${stateFile}")"
            run sh -c 'printf "%s\n" "$1" > "$2"' _ "${qmlSource}" "${stateFile}"

            # The live garden instance: argv is "<wrapper> -c garden".
            # Its comm is the truncated ".quickshell-wra", so match argv.
            pid=$(${pgrep} -u "$USER" -f -- '/quickshell -c garden$' | head -n1)
            [ -n "$pid" ] || return 0

            # niri comes from the consumer (wrapped with nixGL on foreign
            # distros); look in the profile, not the activation PATH.
            niri_bin=$(PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH" command -v niri || true)
            if [ -z "''${NIRI_SOCKET:-}" ] || [ -z "$niri_bin" ]; then
              echo "garden: QML changed; restart the shell from inside the niri session:"
              echo "  pkill -f 'quickshell -c garden\$'; niri msg action spawn -- qs -c garden"
              return 0
            fi

            argv0=$(tr '\0' '\n' < "/proc/$pid/cmdline" | head -n1)
            echo "garden: QML changed, restarting the shell (pid $pid)"
            run kill "$pid"
            for _ in 1 2 3 4 5 6 7 8 9 10; do
              kill -0 "$pid" 2>/dev/null || break
              sleep 0.2
            done
            run "$niri_bin" msg action spawn -- "$argv0" -c garden
          }
          garden_restart || echo "garden: shell restart skipped (error ignored)"
        '';

      # NOTE: Niri config is managed by the consumer (e.g. fern) via
      # programs.niri.settings. The consumer is responsible for wiring
      # keybinds to garden overlay IPC (toggleLauncher, toggleSwitcher).
    };
  };
}
