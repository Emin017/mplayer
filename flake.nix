{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      parts,
      treefmt-nix,
      ...
    }:
    parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        {
          inputs',
          self',
          pkgs,
          system,
          ...
        }:
        {
          devShells = {
            default = pkgs.mkShell {
              nativeBuildInputs = with pkgs; [
                swiftformat
                swiftlint
              ];
              shellHook = ''
                echo "Welcome to the development shell for mplayer!"
                echo "Available tools: swiftformat, swiftlint"
              '';
            };
          };
          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              nixfmt.package = pkgs.nixfmt-rfc-style;
              yamlfmt.enable = true;
            };
            flakeCheck = true;
          };
        };
    };
}
