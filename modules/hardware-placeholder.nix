{ config, lib, pkgs, ... }:
{
  # Placeholder hardware profile for evaluation and CI.
  # Replace with host-specific `nixos-generate-config` output when available.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  swapDevices = [];
}
