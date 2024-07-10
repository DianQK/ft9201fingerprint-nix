{ pkgs ? import <nixpkgs> { } }: rec {
  fprintd-ft9201 = pkgs.callPackage ./pkgs/fprintd-ft9201 { };
}
