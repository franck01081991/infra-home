# TODO: Replace with `nixos-generate-config` output from rpi4-1 when hardware is finalized.
{ config, lib, pkgs, ... }: {
  imports = [ ../../modules/hardware-placeholder.nix ];
}
