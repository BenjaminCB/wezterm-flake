{
  description = "A flake for wezterm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages.wezterm = import ./wezterm.nix { inherit pkgs; };
        defaultPackage = self.packages.${system}.wezterm;
      }
    );
}
