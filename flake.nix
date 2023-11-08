{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=4d2b37a84fad1091b9de401eb450aae66f1a741e";
    hackage = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };
    flake-compat.url = "github:enobayram/flake-compat";
    nixpkgs-rec.url = "github:NixOS/nixpkgs?rev=4d2b37a84fad1091b9de401eb450aae66f1a741e";
    haskellNix = {
      url = "github:input-output-hk/haskell.nix";
      inputs = {
        hackage.follows = "hackage";
        HTTP.follows = "empty";
        stackage.follows = "empty";
        cardano-shell.follows = "empty";
        cabal-32.follows = "empty";
        cabal-34.follows = "empty";
        cabal-36.follows = "empty";
        "ghc-8.6.5-iohk".follows = "empty";
        "hls-1.10".follows = "empty";
        "hls-2.0".follows = "empty";
        "hls-2.2".follows = "empty";
        hpc-coveralls.follows = "empty";
        nixpkgs-2003.follows = "empty";
        nixpkgs-2105.follows = "empty";
        nixpkgs-2111.follows = "empty";
        nixpkgs-2205.follows = "empty";
        nixpkgs-2211.follows = "empty";
        nixpkgs-2305.follows = "empty";
        old-ghc-nix.follows = "empty";
        iserv-proxy.follows = "empty";
        hydra.follows = "empty";
        ghc980.follows = "empty";
        ghc99.follows = "empty";
      };
    };
    empty = {
      url = "github:kadena-io/empty";
      flake = false;
    };
  };
  outputs = inputs@{...}: {
    inherit (inputs) nixpkgs haskellNix;
    lib = rec {
      runRecursiveBuild = system: name: env: cmd: let
        pkgs = inputs.nixpkgs-rec.legacyPackages.${system};
        buildInRec-nix = pkgs.writeText "buildInRec.nix" ''
          {flake}: let
            src = "''${flake}";
            fetchTarball = (import ${inputs.nixpkgs-rec} {}).fetchzip;
            defaultNix = (import ${inputs.flake-compat} { inherit src fetchTarball; }).defaultNix;
            in defaultNix
        '';
        buildInRec = pkgs.writeShellScriptBin "nix-build-flake" ''
          nix-build ${buildInRec-nix} --arg flake "$1" -A "$2" "''${@:3}"
        '';
        in
          pkgs.runCommand name
            (env // {
              requiredSystemFeatures = [ "recursive-nix" ] ++ env.requiredSystemFeatures or [];
              NIX_PATH = "nixpkgs=${inputs.nixpkgs-rec}";
              buildInputs = [ buildInRec pkgs.nix ] ++ env.buildInputs or [];
            }) cmd;
    };
  };
}