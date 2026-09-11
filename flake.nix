{
  description = "Julia environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Override the Nix package set to allow unfree packages
        pkgs = import nixpkgs {
          system = system; 
          config.allowUnfree = true; 
        };
        # WARN: Nix packaging system doesn't support all packages, so rely on Julia package manager instead.
        # Use Julia in REPL mode, then package mode and install packages that way.
        julia = pkgs.julia-bin.overrideDerivation (oldAttrs: { doInstallCheck = false; });
      in
      {
        # development environment
        devShells.default = pkgs.mkShell {
          packages = [
            julia
            pkgs.ghostscript
            # LaTeX
            pkgs.texlive.combined.scheme-full
          ];

          shellHook = ''
            export JULIA_NUM_THREADS="auto"
            export JULIA_PROJECT="."
            export JULIA_BINDIR=${julia}/bin
            export JULIA_EDITOR="code"
            echo "Nix shell loaded."
          '';
        };
      }
    );
}