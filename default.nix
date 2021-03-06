#Adapted from Sukant Hajra's awesome work: https://github.com/shajra/example-nix
let
    default =
        {
            nixpkgs = import <nixpkgs> {};
            nixpkgsArgs = {};
            overlay = import ./overrides/nixpkgs;
            srcFilter = p: t:
                baseNameOf p != "result" && baseNameOf p != ".git";
            haskellArgs = {};
        };

in

{ nixpkgs ? default.nixpkgs
, nixpkgsArgs ? default.nixpkgsArgs
, srcFilter ? default.srcFilter
, nixpkgsOverlay ? default.overlay
, haskellArgs ? default.haskellArgs
}:

generator:

let

    morePkgs = self: super:
        let
            hArgs = { nixpkgs = self; inherit pkgs; } // haskellArgs;
            h = import ./haskell.nix hArgs;
            extnPkgs = import ./tools self.callPackage;
        in
        {
            haskellPackages = h.haskellPackages;
            pkgsMake = {
                args = {
                    call = {
                        haskell = {
                            lib = h.callHaskellLib;
                            app = h.callHaskellApp;
                        };
                    };
                };
                env = { haskell = h.env; };
            };
        } // extnPkgs // pkgs;

    overlays = [ nixpkgsOverlay morePkgs ];

    # reimport supplied nixpkgs using the given overlays and args
    modifiedPkgs =
        import nixpkgs.path
            (nixpkgsArgs // { inherit overlays; });

    callPackage = p:
        let pkg = (modifiedPkgs.callPackage (import p) {});
        in
        if pkg ? overrideAttrs
        then pkg.overrideAttrs (attrs:
            if attrs ? src
            then { src = builtins.filterSource srcFilter attrs.src; }
            else {})
        else pkg;

    generatorArgs = {
        lib = import ./lib modifiedPkgs;
        call = {
            package = callPackage;
            haskell = modifiedPkgs.pkgsMake.args.call.haskell;
        };
    };

    pkgs = generator generatorArgs;

in

pkgs // { inherit modifiedPkgs; env = modifiedPkgs.pkgsMake.env; }
