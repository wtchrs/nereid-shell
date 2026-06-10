{
  pkgs,
  lib,
  umuExeList ? "/nonexistent/nereid-shell/umu-exe-list",
}:

let
  appName = "nereid-shell";

  configRoot = pkgs.runCommand "${appName}-config" { } ''
    mkdir -p "$out"
    cp -r ${../config}/. "$out/"
  '';

  awkFile = pkgs.writeText "quickshell-program-list.awk" (
    builtins.readFile ../scripts/quickshell-program-list.awk
  );

  quickshellProgramList = pkgs.replaceVarsWith {
    src = ../scripts/quickshell-program-list.sh;
    replacements = {
      awkFile = "${awkFile}";
      awk = "${pkgs.gawk}/bin/awk";
      find = "${pkgs.findutils}/bin/find";
      jq = "${pkgs.jq}/bin/jq";
      inherit umuExeList;
    };
    dir = "bin";
    isExecutable = true;
  };

  runtimeDeps = with pkgs; [
    brightnessctl
    findutils
    gawk
    ghostty
    jq
    libnotify
    networkmanager
    niri
    pulseaudio
    quickshell
    wireplumber
  ];

  runtimePath = lib.makeBinPath ([ quickshellProgramList ] ++ runtimeDeps);
in
pkgs.symlinkJoin {
  name = appName;

  paths = [
    pkgs.quickshell
    quickshellProgramList
  ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    makeWrapper ${pkgs.quickshell}/bin/qs "$out/bin/nereid-shell" \
      --set QS_CONFIG_PATH ${configRoot} \
      --prefix PATH : ${runtimePath} \
      --add-flags "--path ${configRoot}"

    makeWrapper ${pkgs.quickshell}/bin/qs "$out/bin/nereid-shell-ctl" \
      --set QS_CONFIG_PATH ${configRoot} \
      --prefix PATH : ${runtimePath} \
      --add-flags "--path ${configRoot} ipc"
  '';

  passthru = {
    inherit configRoot quickshellProgramList;
  };

  meta = {
    description = "Nereid Shell Quickshell configuration and launcher";
    mainProgram = "nereid-shell";
    platforms = lib.platforms.linux;
  };
}
