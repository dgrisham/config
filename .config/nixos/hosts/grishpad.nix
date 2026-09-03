{ config, pkgs, ... }:

# grishpad — ThinkPad T480 (Intel UHD 620). Delta over ../common.nix.

{
  imports = [ ../common.nix ];

  boot.loader.systemd-boot.configurationLimit = 4;

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/b5321c29-e3e9-43ef-835c-379df678dadf";
    fsType = "ext4";
  };

  networking.hostName = "grishpad";
  networking.wireless.iwd.enable = true;   # iwd does its own DHCP
  networking.wireless.iwd.settings.General.EnableNetworkConfiguration = true;

  services.openssh.settings.PasswordAuthentication = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # backlight writable by the video group
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", GROUP="video", MODE="0664"
  '';

  users.users.grish.shell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    iwd            # iwctl
    bluez          # bluetoothctl
    acpi
    arandr
    brightnessctl
    xrandr
  ];

  system.stateVersion = "26.05";
}
