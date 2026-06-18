# Nereid Shell

This is Nereid Shell, which is Quickshell-based desktop shell configuration for Niri.

## Nix Profile

Install from GitHub:

```sh
nix profile install github:wtchrs/nereid-shell
```

Or install from a local checkout:

```sh
nix profile install .
```

Run it:

```sh
nereid-shell
```

Control the running shell:

```sh
nereid-shell-ctl call appLauncher toggle
```

## Home Manager

Add the flake input:

```nix
inputs.nereid-shell.url = "github:wtchrs/nereid-shell";
```

Import and enable the module in your Home Manager configuration:

```nix
{
  imports = [
    inputs.nereid-shell.homeManagerModules.default
  ];

  programs.nereid-shell = {
    enable = true;
    niriIntegration.enable = true;
  };
}
```

`niriIntegration.enable` adds startup integration and keybinds for the launcher
and wallpaper reload when the Home Manager Niri module is available.
