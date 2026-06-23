{ pkgs, ... }:

  ###################################################################################
  #
  #  macOS's System configuration
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  #
  ###################################################################################
{
  system = {
    stateVersion = 5;

    defaults = {
      menuExtraClock.Show24Hour = true;  # show 24 hour clock

      # customize dock
      dock = {
        autohide = true;
        show-recents = false;  # disable recent apps

        # customize Hot Corners
        wvous-tl-corner = 2;  # top-left - Mission Control
        wvous-bl-corner = 3;  # bottom-left - Application Windows
        wvous-br-corner = 4;  # bottom-right - Desktop
      };
      # customize finder
      finder = {
        _FXShowPosixPathInTitle = true;  # show full path in finder title
        AppleShowAllExtensions = true;  # show all file extensions
        FXEnableExtensionChangeWarning = false;  # disable warning when changing file extension
        QuitMenuItem = true;  # enable quit menu item
        ShowPathbar = true;  # show path bar
        ShowStatusBar = true;  # show status bar
      };
      # customize trackpad
      trackpad = {
        Clicking = true;  # enable tap to click
        TrackpadRightClick = true;  # enable two finger right click
        TrackpadThreeFingerDrag = true;  # enable three finger drag
      };
      NSGlobalDomain = {
        # `defaults read NSGlobalDomain "xxx"`
        "com.apple.swipescrolldirection" = true;  # enable natural scrolling(default to true)
        "com.apple.sound.beep.feedback" = 0;  # disable beep sound when pressing volume up/down key
        AppleInterfaceStyle = "Dark";  # dark mode
        AppleKeyboardUIMode = 3;  # Mode 3 enables full keyboard control.
        ApplePressAndHoldEnabled = true;  # enable press and hold

        # If you press and hold certain keyboard keys when in a text area, the key’s character begins to repeat.
        # This is very useful for vim users, they use `hjkl` to move cursor.
        # sets how long it takes before it starts repeating.
        InitialKeyRepeat = 15;  # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
        # sets how fast it repeats once it starts. 
        KeyRepeat = 3;  # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = false;  # disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false;  # disable auto dash substitution
        NSAutomaticPeriodSubstitutionEnabled = false;  # disable auto period substitution
        NSAutomaticQuoteSubstitutionEnabled = false;  # disable auto quote substitution
        NSAutomaticSpellingCorrectionEnabled = false;  # disable auto spelling correction
        NSNavPanelExpandedStateForSaveMode = true;  # expand save panel by default
        NSNavPanelExpandedStateForSaveMode2 = true;
      };
      screencapture = {
         location = "~/screenshots";
         type = "png";
       };
    };
    keyboard = {
        enableKeyMapping = true;  # enable key mapping so that we can use `option` as `control`

        # NOTE: do NOT support remap capslock to both control and escape at the same time
        remapCapsLockToControl = false;  # remap caps lock to control, useful for emac users
        remapCapsLockToEscape  = false;   # remap caps lock to escape, useful for vim users

        # swap left command and left alt 
        # so it matches common keyboard layout: `ctrl | command | alt`
        #
        # disabled, caused only problems!
      };
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;
  # programs.git = {
  #   enable = true;
  #   lfs.enable = true;
  # };

  time.timeZone = "Europe/Athens";
  # Fonts
  fonts.packages = with pkgs; [
    pkgs.material-design-icons
    pkgs.font-awesome

  # symbols icon only
  nerd-fonts.symbols-only
  # Characters
  nerd-fonts.fira-code
  nerd-fonts.jetbrains-mono
  nerd-fonts.iosevka
  nerd-fonts.hack
  ];
  # fonts = {
  #   packages = with pkgs; [
  #     # icon fonts
  #
  #     # nerdfonts
  #     # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/pkgs/data/fonts/nerdfonts/shas.nix
  #     (nerdfonts.override {
  #       fonts = [
  #         # symbols icon only
  #         "NerdFontsSymbolsOnly"
  #         # Characters
  #         "FiraCode"
  #         "JetBrainsMono"
  #         "Iosevka"
  #       ];
  #     })
  #   ];
  # };

}
