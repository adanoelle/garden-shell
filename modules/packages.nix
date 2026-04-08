# modules/packages.nix — Nix packages for Rust crates + QML
{ inputs, ... }:
{
  perSystem = { pkgs, system, self', ... }:
    let
      rustPkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.rust-overlay.overlays.default ];
      };

      commonArgs = {
        version = "0.1.0";
        src = ./..;
        cargoLock.lockFile = ../Cargo.lock;
      };
    in
    {
      packages = {
        garden-daemon = pkgs.rustPlatform.buildRustPackage (commonArgs // {
          pname = "garden-daemon";
          cargoBuildFlags = [ "-p" "garden-daemon" ];
        });

        garden-ctl = pkgs.rustPlatform.buildRustPackage (commonArgs // {
          pname = "garden-ctl";
          cargoBuildFlags = [ "-p" "garden-ctl" ];
        });

        garden-tui = pkgs.rustPlatform.buildRustPackage (commonArgs // {
          pname = "garden-tui";
          cargoBuildFlags = [ "-p" "garden-tui" ];
        });

        garden-themes = pkgs.rustPlatform.buildRustPackage (commonArgs // {
          pname = "garden-themes";
          cargoBuildFlags = [ "-p" "garden-themes" ];
        });

        garden-themes-output = pkgs.runCommand "garden-themes-output"
          {
            nativeBuildInputs = [ self'.packages.garden-themes ];
          } ''
          garden-themes generate \
            --palettes ${../_config/palettes.toml} \
            --output $out
        '';

        garden-shell-qml = pkgs.stdenvNoCC.mkDerivation {
          pname = "garden-shell-qml";
          version = "0.1.0";
          src = ../_qml;
          installPhase = ''
            mkdir -p $out/share/quickshell/garden
            cp -r . $out/share/quickshell/garden/
          '';
        };
      };
    };
}
