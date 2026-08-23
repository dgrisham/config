{ config, pkgs, ... }:

# Shared base for all hosts. Each host imports this + its own hosts/<hostname>.nix.

{
  imports = [
    /etc/nixos/hardware-configuration.nix   # per-host, from nixos-generate-config
  ];

  boot.loader.systemd-boot.enable = true;   # configurationLimit set per-host
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.pulseaudio.enable = false;

  services.openssh.enable = true;   # PasswordAuthentication set per-host

  hardware.graphics.enable = true;

  # X, no display manager: startx into dwm via ~/.config/x11/xinitrc
  services.xserver.enable = true;
  services.xserver.displayManager.startx.enable = true;
  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  location.latitude = 39.74;
  location.longitude = -104.99;
  services.redshift = {
    enable = true;
    temperature.day = 5500;
    temperature.night = 3700;
  };

  nixpkgs.config.allowUnfree = true;   # brave, vscode

  fonts.packages = with pkgs; [ freefont_ttf inconsolata nerd-fonts.inconsolata ];

  users.users.grish = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];   # hosts append more (list-merged)
    initialPassword = "changeme";        # run `passwd` on first login
    # shell set per-host
  };

  programs.nix-ld.enable = true;
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [ urlview ];
  };
  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    '';
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    parted git sxhkd fzf perl xrdb setxkbmap xmodmap herbe w3m jq yt-dlp
    pulseaudio pavucontrol rsync scrot go go-task gcc silver-searcher unzip
    xclip xdotool zathura zbar lazygit lf tmux feh flameshot gimp fossil openssh
    (pass.withExtensions (exts: [ exts.pass-otp ])) exfatprogs dosfstools
    brave vscode jellyfin-mpv-shim inetutils unclutter-xfixes xev
    claude-code nushell http-nu mpv zsh-history-substring-search diceware

    # kakoune master; impure fetch (no rev) re-fetched each rebuild — fine, not a flake
    (kakoune-unwrapped.overrideAttrs (old: {
      src = builtins.fetchGit { url = "https://github.com/mawww/kakoune.git"; ref = "master"; };
    }))

    # suckless builds from ~/src. autoPatchelfHook bakes the runtime rpath (their
    # config.mk hardcodes /usr/local/lib), else the binaries can't find libX11 at runtime.
    (dwm.overrideAttrs   (old: { src = /home/grish/src/dwm;   nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ autoPatchelfHook ]; buildInputs = (old.buildInputs or []) ++ [ fontconfig ]; }))
    (st.overrideAttrs    (old: { src = /home/grish/src/st;    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ autoPatchelfHook ]; buildInputs = (old.buildInputs or []) ++ [ fontconfig ]; }))
    (dmenu.overrideAttrs (old: { src = /home/grish/src/dmenu; nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ autoPatchelfHook ]; buildInputs = (old.buildInputs or []) ++ [ fontconfig ]; }))
  ];
}
