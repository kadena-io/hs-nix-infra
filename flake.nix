{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=4d2b37a84fad1091b9de401eb450aae66f1a741e";

    # We're declaring hackage as a direct input to this flake so that downstream
    # flakes can override it.
    hackage = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };
    haskellNix = {
      url = "github:input-output-hk/haskell.nix";

      # This allows downstream flakes to override hackage through this flake
      inputs.hackage.follows = "hackage";

      # We're trimming down the haskell.nix inputs to remove the ones that we don't
      # depend on in our own projects. haskell.nix comes with a lot of inputs that
      # are used by different kinds of Haskell projects. By trimming down these inputs,
      # we're reducing the amount of clutter that ends up in the flake.lock files of
      # downstream flakes.
      #
      # These overrides can potentially cause Nix evaluation failures in the future
      # in which case we can remove offending entries. We should also take care to
      # override any new unused inputs that are added to haskell.nix in the future.
      inputs = {
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

    # === Inputs for the recursive-nix utilities ===

    # This version of flake-compat allows us to replace fetchTarball with fetchzip
    # We can revert to upstream once https://github.com/edolstra/flake-compat/pull/62 is in
    flake-compat.url = "github:kadena-io/flake-compat";

    # !!!IMPORTANT!!!
    # This nixpkgs version is used by the recursive-nix utilities for provisioning the
    # recursive-nix build environment. We should refrain from changing its revision unless
    # absolutely necessary, because this input is a Nix-eval time dependency of the recursive
    # derivation itself, which means downstream users will have to download a new nixpkgs version
    nixpkgs-rec.url = "github:NixOS/nixpkgs?rev=4d2b37a84fad1091b9de401eb450aae66f1a741e";
  };
  outputs = inputs@{...}: {
    # Downstream Haskell projects should use nixpkgs and haskellNix from this flake
    # In order to make sure that the GHC derivations are consisten across projects
    inherit (inputs) nixpkgs haskellNix;

    # Utilities for building flake outputs inside recursive-nix derivations
    lib.recursive = system: let pkgs = inputs.nixpkgs-rec.legacyPackages.${system}; in rec {
      # runRecursiveBuild is a variant of pkgs.runCommand that sets up a recursive-nix
      # environment. It sets up an env that declares the recursive-nix feature and also
      # provides the nix CLI and a NIX_PATH. The advantage of using this utility is that
      # it allows us to reuse the `nixpkgs` revision across all recursive-nix builds. This
      # is important because the nixpkgs revision is a Nix-eval time dependency of the
      # recursive derivation.
      runRecursiveBuild = name: env: cmd: pkgs.runCommand name
        (env // {
          requiredSystemFeatures = [ "recursive-nix" ] ++ env.requiredSystemFeatures or [];
          NIX_PATH = "nixpkgs=${inputs.nixpkgs-rec}";
          buildInputs = [ pkgs.nix ] ++ env.buildInputs or [];
        }) cmd;

      # This is a utility for building a .nix file that wraps a given flake so that it can
      # be built as a raw Nix expression inside a recursive-nix derivation. For example
      #
      #  ln -s $(nix-build ${wrapFlake self} -A default) $out
      wrapFlake = flake: pkgs.writeText "wrapped-flake.nix" ''
        let
          src = "${flake}";
          fetchTarball = (import ${inputs.nixpkgs-rec} {}).fetchzip;
          defaultNix = (import ${inputs.flake-compat} { inherit src fetchTarball; }).defaultNix;
        in defaultNix
      '';
    };
  };
}