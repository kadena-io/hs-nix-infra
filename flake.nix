{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=4d2b37a84fad1091b9de401eb450aae66f1a741e";
    hackage = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };
    flake-compat.url = "github:enobayram/flake-compat";
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
      recursiveDeps = inputs: let
          go = currentPath: currentInputs: let
            toInputPath = name: builtins.concatStringsSep "/" (currentPath ++ [name]);
            directDepNames = builtins.attrNames currentInputs;
            directOutPaths = map (name: {
                name = name;
                inputPath = currentPath ++ [name];
                outPath = currentInputs.${name}.outPath;
              }) directDepNames;
            recurseOnName = name: go (currentPath ++ [name]) (currentInputs.${name}.inputs or {});
            transitiveOutPaths = builtins.concatLists (map recurseOnName directDepNames);
          in directOutPaths ++ transitiveOutPaths;
        in go [] inputs;
      recursiveRawFlakeBuilder = pkgs: flake: name: env: cmd: pkgs.runCommand name (env // {
          requiredSystemFeatures = [ "recursive-nix" ] ++ env.requiredSystemFeatures or [];
          FLAKEDEPS = let
            # This function doesn't support building a flake with overridden inputs.
            rawFlakeInputs = (import inputs.flake-compat { src = "${flake}"; fetchTarball = pkgs.fetchzip; }).defaultNix.inputs;
            deps = recursiveDeps rawFlakeInputs;
            depName = dep: "DEP-${builtins.concatStringsSep "/" dep.inputPath}";
            env = builtins.listToAttrs
              (map (dep: { name = depName dep; value = dep.outPath;}) deps);
            in pkgs.runCommand "${name}-flake-deps" env "printenv > $out";
          buildInputs = [ pkgs.nix ] ++ env.buildInputs or [];
          NIX_CONFIG = ''
            experimental-features = nix-command flakes recursive-nix
            substituters =
          '' + env.NIX_CONFIG or "";
        }) ''
          export HOME=$PWD
          ${cmd}
        '';
    };
  };
}