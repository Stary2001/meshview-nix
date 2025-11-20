{
  description = "Flake for meshview using uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
  {
    self,
    nixpkgs,
    uv2nix,
    pyproject-nix,
    pyproject-build-systems,
    ...
  }:
  let
    inherit (nixpkgs) lib;

    forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
    overlay = workspace.mkPyprojectOverlay {
      sourcePreference = "wheel"; # or sourcePreference = "sdist";
    };

    pyprojectOverrides = _final: _prev: {
    };
    pythonSets = forAllSystems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python3;
      in
      (pkgs.callPackage pyproject-nix.build.packages {
        inherit python;
      }).overrideScope
        (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.wheel
            overlay
          ]
        )
    );

  in
  {
    overlays.default = (
      final: prev: {
        meshview = final.lib.makeScope final.newScope (_self: {
          venv = self.packages.${prev.system}.venv;
          src = _self.callPackage ./pkgs/src.nix {};
        });
      }
    );

    packages = forAllSystems (
    system:
    let
      pythonSet = pythonSets.${system};
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      venv = pythonSet.mkVirtualEnv "application-env" workspace.deps.default;
    });

    nixosModules.default = {
      lib,
      pkgs,
      config,
      ...
    }:
    with lib;
    let cfg = config.services.meshview;
    configFile = pkgs.writeText "config.ini" (lib.generators.toINI {} cfg.config);
    # ....... etc
    in {
      options.services.meshview = {
        enable = mkEnableOption (lib.mdDoc "meshview");
        dataDir = mkOption { type = types.path; default = "/var/lib/meshview"; description = lib.mdDoc "Data directory for meshview"; };
        config = {
          server = {
            bind = mkOption {
              type = types.str;
              default = "*";
              description = lib.mdDoc "Bind address";
            };
            port = mkOption {
              type = types.port;
              description = lib.mdDoc "Port to listen on";
            };
          };

          site = {
            domain = mkOption {
              type = types.str;
              description = lib.mdDoc "Domain";
            };
            title = mkOption {
              type = types.str;
              description = lib.mdDoc "Title";
            };
            message = mkOption {
              type = types.str;
              description = lib.mdDoc "Message";
            };
            starting = mkOption {
              type = types.str;
              description = lib.mdDoc "Initial URL";
            };

            nodes = mkOption { type = types.bool; default = true; description = lib.mdDoc "Nodes"; };
            conversations = mkOption { type = types.bool; default = true; description = lib.mdDoc "a"; };
            graphs = mkOption { type = types.bool; default = true; description = lib.mdDoc "a"; };
            stats = mkOption { type = types.bool; default = true; description = lib.mdDoc "a"; };
            net = mkOption { type = types.bool; default = true; description = lib.mdDoc "a"; };
            map = mkOption { type = types.bool; default = true; description = lib.mdDoc "a"; };
            top = mkOption { type = types.bool; default = true; description = lib.mdDoc "a"; };

            map_top_left_lat = mkOption { type = types.str; description = lib.mdDoc "a"; };
            map_top_left_lon = mkOption { type = types.str; description = lib.mdDoc "a"; };
            map_bottom_right_lat = mkOption { type = types.str; description = lib.mdDoc "a"; };
            map_bottom_right_lon = mkOption { type = types.str; description = lib.mdDoc "a"; };

            map_interval = mkOption { type = types.int; description = lib.mdDoc "a"; };
            firehose_interval = mkOption { type = types.int; description = lib.mdDoc "a"; };
          };

          mqtt = {
            server = mkOption { type = types.str; description = lib.mdDoc "MQTT server address"; };
            port = mkOption { type = types.str; description = lib.mdDoc "MQTT server port"; };
            topics = mkOption { type = types.listOf types.str; description = lib.mdDoc "List of topics"; };

            username = mkOption { type = types.str; description = lib.mdDoc "MQTT server username"; };
            password = mkOption { type = types.str; description = lib.mdDoc "MQTT server password"; };
          };

          database = {
            connection_string = mkOption { type = types.str; default = "sqlite+aiosqlite:///packets.db"; description = lib.mdDoc "Database connection URL"; };
          };

          cleanup = {
            enabled = mkOption { type = types.bool; description = lib.mdDoc "Enable daily cleanup"; };
            days_to_keep = mkOption { type = types.int; description = lib.mdDoc "Number of days to keep records in the database"; };
            hour = mkOption { type = types.int; description = lib.mdDoc "Hour to run cleanup (24 hour format)"; };
            minute = mkOption { type = types.int; description = lib.mdDoc "Minute to run cleanup"; };
            vacuum = mkOption { type = types.bool; description = lib.mdDoc "Run VACUUM afterwards"; };
          };

          logging = {
            access_log = mkOption { type = types.bool; description = lib.mdDoc "a"; };
          };
        };
      };

      config = mkIf cfg.enable {
        nixpkgs.overlays = [ self.overlays.default ];
        users.users.meshview = {
          group = "meshview";
          isSystemUser = true;
          description = "meshview daemon";
        };
        users.groups.meshview = {};

        systemd.services.meshview-db = {
          description = "Meshview Database Initializer";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          serviceConfig = {
            Type = "simple";
            User = "meshview";
            Group = "meshview";
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${pkgs.meshview.venv}/bin/python ${pkgs.meshview.src}/startdb.py --config ${configFile}";
            Restart = "always";
            RestartSec = 5;
          };
        };
          
        systemd.services.meshview-web = {
          description = "Meshview web server";
          wantedBy = ["multi-user.target"];
          after = ["network.target" "meshview-db.service"];
          serviceConfig = {
            Type = "simple";
            User = "meshview";
            Group = "meshview";
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${pkgs.meshview.venv}/bin/python ${pkgs.meshview.src}/startdb.py --config ${configFile}";
            Restart = "always";
            RestartSec = 5;
          };
        };
      };
    };
  };
}