{
  description = "Nereid shell, the desktop shell configuration for Quickshell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
      pkgsFor = system: import nixpkgs { inherit system; };

      mkShellPackage =
        system:
        let
          pkgs = pkgsFor system;
        in
        import ./nix/package.nix {
          inherit pkgs;
          inherit (pkgs) lib;
        };
    in
    {
      packages = forAllSystems (system: {
        default = mkShellPackage system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/nereid-shell";
        };
      });

      homeManagerModules.default = import ./nix/home-manager.nix { inherit self; };

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nil
              nixd
              nixfmt-rfc-style
              quickshell
              statix
            ];
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);
    };
}
