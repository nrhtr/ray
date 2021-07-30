{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig

    # keep this line if you use bash
    pkgs.bashInteractive
  ];
}
