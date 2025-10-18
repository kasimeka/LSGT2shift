{
  nixConfig.bash-prompt-prefix = ''(LSGT2shift) '';
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: let
    outputs = inputs.self.outputs;

    forAllSystems = f:
      inputs.nixpkgs.lib.genAttrs
      (import inputs.systems)
      (system: f inputs.nixpkgs.legacyPackages.${system});

    pname = "lsgt2shift";

    mkStdenv = pkgs: pkgs.pkgsMusl.stdenv;
    mkDrv = pkgs:
      (mkStdenv pkgs).mkDerivation {
        inherit pname;
        version = "v1.0.0";

        src = with pkgs.lib.fileset;
          toSource {
            root = ./.;
            fileset = unions [
              ./build.sh
              (fileFilter (file: file.hasExt "c" || file.hasExt "h") ./.)
            ];
          };

        buildPhase = ''$SHELL build.sh'';
        installPhase = ''install -Dm755 ${pname} $out/bin/${pname}'';

        meta.mainProgram = pname;
      };
  in rec {
    devShells = forAllSystems (pkgs: {
      default = (pkgs.mkShell.override {stdenv = mkStdenv pkgs;}) {
        inputsFrom = [outputs.packages.${pkgs.system}.default];
        packages = [pkgs.clang-tools];
      };
    });

    packages = forAllSystems (pkgs: {
      default = outputs.packages.${pkgs.system}.${pname};
      ${pname} = mkDrv pkgs;
    });

    overlays.default = overlays.${pname};
    overlays.${pname} = _: prev: {
      interception-tools-plugins =
        prev.interception-tools-plugins // {${pname} = outputs.packages.${prev.system}.default;};
    };

    nixosModules.default = nixosModules.${pname};
    nixosModules.${pname} = {
      config,
      pkgs,
      lib,
      ...
    }: {
      options.janw4ld.lsgt2shift.enable =
        lib.mkEnableOption "enable lsgt2shift interception-tools plugin";

      config = lib.mkIf config.janw4ld.lsgt2shift.enable {
        nixpkgs.overlays = [outputs.overlays.default];
        services.interception-tools = {
          enable = lib.mkDefault true;
          udevmonConfig = with pkgs; let
            intercept = lib.getExe' interception-tools "intercept";
            uinput = lib.getExe' interception-tools "uinput";
            lsgt2shift = lib.getExe pkgs.interception-tools-plugins.${pname};
          in
            lib.mkDefault (builtins.toJSON [
              {
                JOB = "${intercept} -g $DEVNODE | ${lsgt2shift} | ${uinput} -d $DEVNODE";
                DEVICE.EVENTS.EV_KEY = ["KEY_102ND"];
              }
            ]);
        };
      };
    };
  };
}
