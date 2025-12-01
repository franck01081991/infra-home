# TODO: Replace with `nixos-generate-config` output from rpi3a-ctl when hardware is finalized.
{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/hardware-placeholder.nix
  ];
}
