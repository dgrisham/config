{ config, pkgs, ... }:

{
  imports = [
    # Generated fresh by `nixos-generate-config --root /mnt` at install time.
    # Copy that generated file in next to this one before nixos-install.
    ./hardware-configuration.nix
  ];

  # --- Bootloader ---
  # systemd-boot, not GRUB: single-OS UEFI box, and NixOS generations need
  # an actual boot menu (current Arch setup has none - bare EFISTUB).
  boot.loader.systemd-boot.enable = true;
  # ESP is 512M. Each generation keeps a kernel+initrd there (~60-80M), and the
  # default is unlimited - capping boot entries keeps `nixos-rebuild` from
  # eventually failing on a full /boot. Older generations still exist in the
  # store and are reachable via `nixos-rebuild --rollback`, just not the menu.
  boot.loader.systemd-boot.configurationLimit = 4;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/b5321c29-e3e9-43ef-835c-379df678dadf";
    fsType = "ext4";
  };

  # --- Networking ---
  networking.hostName = "grishpad";
  networking.wireless.iwd.enable = true;
  # iwd does its own DHCP so bin/wifi doesn't need a separate dhcpcd step.
  networking.wireless.iwd.settings.General.EnableNetworkConfiguration = true;

  # --- Time / locale ---
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Audio: PipeWire ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  # Explicitly off - PulseAudio is being replaced, not run alongside PipeWire's pulse shim.
  services.pulseaudio.enable = false;

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # --- Graphics (Intel UHD 620 / i915, ThinkPad T480) ---
  hardware.graphics.enable = true;

  # --- X server, no display manager: startx into dwm via ~/.config/x11/xinitrc ---
  services.xserver.enable = true;
  services.xserver.displayManager.startx.enable = true;
  # caps->ctrl baked into every X server start, instead of bin/caps-to-ctrl/bin/dock
  # needing to re-run `setxkbmap` by hand after updates/restarts.
  services.xserver.xkb.options = "ctrl:nocaps";

  # keymaps in tty too
  console.useXkbConfig = true;

  location.latitude = 39.74;
  location.longitude = -104.99;
  services.redshift = {
    enable = true;
    temperature.day = 5500;
    temperature.night = 3700;
  };

  # brave and vscode are both marked unfree in nixpkgs.
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    parted
    git
    sxhkd
    fzf
    iwd
    perl
    xrdb
    setxkbmap
    xmodmap
    herbe
    w3m
    jq
    yt-dlp
    pulseaudio   # for `pactl` (bin/btmenu) - client tools only, server is PipeWire
    #runit

    lazygit
    lf
    tmux
    acpi
    arandr
    brightnessctl
    exfatprogs
    dosfstools
    feh
    flameshot
    gimp
    fossil
    openssh
    (pass.withExtensions (exts: [ exts.pass-otp ]))
    pavucontrol
    rsync
    scrot
    silver-searcher
    unzip
    xclip
    xdotool
    zathura
    zbar

    brave
    vscode
    jellyfin-mpv-shim
    inetutils
    unclutter-xfixes   # actively maintained fork; base `unclutter` is stale upstream
    xev
    xrandr
    # playerctl

    claude-code

    mpv

    # zsh-history-substring-search has no dedicated NixOS module option like the other
    # two zsh plugins below - stays a plain package + the existing `source` line in .zshrc.
    zsh-history-substring-search

    diceware
    # No nixpkgs package covers ex-vi-compat's role - left out rather than guessed.

    # Tracks kakoune's master branch, not the last tagged release nixpkgs pins to.
    # Impure fetch (no `rev`) is fine here since this file isn't a flake - each
    # `nixos-rebuild switch` re-fetches current master, but the resulting build is
    # still a normal immutable generation, so rollback still works if master breaks.
    (kakoune-unwrapped.overrideAttrs (old: {
      src = builtins.fetchGit {
        url = "https://github.com/mawww/kakoune.git";
        ref = "master";
      };
    }))

    (dwm.overrideAttrs   (old: { src = /home/grish/src/dwm;   }))
    (st.overrideAttrs    (old: { src = /home/grish/src/st;    }))
    (dmenu.overrideAttrs (old: { src = /home/grish/src/dmenu; }))
  ];

  fonts.packages = with pkgs; [
    freefont_ttf
    inconsolata
    nerd-fonts.inconsolata
  ];

  # --- User account ---
  users.users.grish = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    # Throwaway - this string is world-readable in the nix store.
    # Run `passwd` on first login and change it.
    initialPassword = "changeme";
  };
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    '';
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bump only on deliberate, understood changes - see NixOS docs on stateVersion.
  system.stateVersion = "26.05";
}
