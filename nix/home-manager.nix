{ self }:

{
  lib,
  config,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.nereid-shell;
  system = pkgs.stdenv.hostPlatform.system;
  defaultPackage = self.packages.${system}.default;
  hasNiriSettings =
    options ? programs
    && options.programs ? niri
    && options.programs.niri ? settings;
in
{
  options.programs.nereid-shell = {
    enable = lib.mkEnableOption "Nereid Quickshell configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "inputs.nereid-shell.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "Nereid Shell package to install.";
    };

    enableQuickshellProgram = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Home Manager's programs.quickshell module.";
    };

    niriIntegration.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to add minimal Niri startup and IPC keybind integration.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];

        programs.quickshell.enable = cfg.enableQuickshellProgram;
      }

      (lib.mkIf (cfg.niriIntegration.enable && hasNiriSettings) {
        programs.niri.settings = {
          spawn-at-startup = [
            { argv = [ "nereid-shell" "--no-duplicate" ]; }
          ];

          binds = {
            "Mod+Space" = {
              hotkey-overlay.title = "Run an Application: quickshell app launcher";
              action.spawn = [
                "nereid-shell-ctl"
                "call"
                "appLauncher"
                "toggle"
              ];
            };

            "Mod+Shift+W" = {
              hotkey-overlay.title = "Reload wallpaper: quickshell";
              action.spawn = [
                "nereid-shell-ctl"
                "call"
                "wallpaper"
                "reload"
              ];
            };
          };
        };
      })
    ]
  );
}
