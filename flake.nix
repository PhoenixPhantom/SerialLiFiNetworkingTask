{
   inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      flake-utils.url = "github:numtide/flake-utils";

      odinlang = {
         url = "github:PhoenixPhantom/odin-flake";
         inputs = {
            nixpkgs.follows = "nixpkgs";
            flake-utils.follows = "flake-utils";
         };
      };

      odin-ls = {
         url = "github:PhoenixPhantom/ols-flake";
         inputs = {
            nixpkgs.follows = "nixpkgs";
            flake-utils.follows = "flake-utils";
         };
      };
   };
   outputs = { self, nixpkgs, flake-utils, odin-ls, odinlang }:
   flake-utils.lib.eachDefaultSystem 
      (system: 
      let
         overlays = [ odin-ls.overlays.default odinlang.overlays.default ];
         pkgs = import nixpkgs {
            inherit system overlays;
         };
      in
      with pkgs;
      {
         devShells.default = mkShell {
            name = "Arduino-Networking";
            buildInputs = [
               ols
               odin
               (pkgs.python3.withPackages (python-pkgs: with python-pkgs; [
                  numpy
                  matplotlib
                  scipy
                  jedi-language-server
                  ipython
                  #  matplotlib gtk4cairo rendering backend
                  pycairo
                  pygobject3
               ]))
            ];
            MPLBACKEND="gtk4cairo";
         };
      }
   );
}
