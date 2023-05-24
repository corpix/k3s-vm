{ pkgs, lib, ... }:
let
  inherit (lib)
    concatStringsSep
    concatMapStringsSep
    listToAttrs
  ;
  inherit (pkgs)
    stdenv
    writeScript
    dockerTools
    runCommand
  ;

  unregistry = { pkgs ? import <nixpkgs> {}, ... }:
    pkgs.buildGoModule rec {
      name = "unregistry";
      version = "0.0.1";
      src = pkgs.fetchgit {
        url = "https://github.com/corpix/unregistry";
        rev = version;
        sha256 = "1bh8p9wsyjn5snhp5vijfbsbr7hsync3b1w6gch8inwl1iad0xca";
      };
      vendorSha256 = null;
    };

  containers = [
    (dockerTools.buildLayeredImage
      {
        name = "sleep";
        contents = with pkgs; [busybox];
        config.Cmd = ["${pkgs.busybox}/bin/sleep" "9999999"];
      })
    (dockerTools.buildLayeredImage
      {
        name = "true";
        contents = with pkgs; [busybox];
        config.Cmd = ["${pkgs.busybox}/bin/true"];
      })
  ];
in {
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>

    ./services/unregistry.nix
  ];

  config = {
    environment.enableAllTerminfo = true;
    environment.systemPackages =
      let
        k9sWrapper = writeScript "k9s" ''
          #! ${stdenv.shell} -e
          exec ${pkgs.k9s}/bin/k9s --kubeconfig /etc/rancher/k3s/k3s.yaml $@
        '';
        wrappers = stdenv.mkDerivation {
          name = "wrappers";
          builder = writeScript "builder.sh" ''
             #! ${stdenv.shell} -e
             export PATH=${pkgs.coreutils}/bin
             mkdir -p $out/bin
             ${concatMapStringsSep "\n" (wrapper: "ln -s ${wrapper} $out/bin/${wrapper.name}") [
               k9sWrapper
             ]}
          '';
        };
        packages = with pkgs; [
          kubectl
          fish
          htop
          iotop
          mc
          vim
          iputils
          inetutils
          jq
          rsync
          tree
        ];
      in packages ++ [ wrappers ];

    users.extraUsers.root = {
      shell = "${pkgs.fish}/bin/fish";
      password = "";
    };


    programs = {
      command-not-found.enable = false;
      fish = {
        enable = true;
        promptInit = ''
           function prompt_hostname
             # return the short hostname only by default (#4804)
             printf "%s" (string replace -r "\..*" "" $hostname)
           end
        '';
      };
    };
    ##

    networking.firewall.allowedTCPPorts = [
      6443 # k3s
    ];

    services = {
      openssh = {
        enable = true;
        settings = {
          UseDns = false;
          PermitRootLogin = "yes";
          PasswordAuthentication = true;
          PermitEmptyPasswords = "yes";
        };
        openFirewall = true;
      };
      k3s = {
        enable = true;
        extraFlags = concatStringsSep " " [
          "--disable" "traefik"
          "--cluster-domain" "cluster"
        ];
      };
      nfs.server = {
        enable = true;
        exports = ''
          /nfs 127.0.0.1(rw,fsid=0,no_subtree_check)
        '';
      };
      unregistry = {
        enable = true;
        config = {
          log.level = "info";
          registry = rec {
            server.addr = "localhost:2789";
            provider = {
              type = "local";

              local.containers = let
                extract = container: {
                  name = "${container.imageName}:latest";
                  value = runCommand "${container.imageName}-layers" {}
                    ''
                       mkdir -p $out
                       ${pkgs.gnutar}/bin/tar -xf ${container} -C $out
                     '';
                };
              in listToAttrs (map extract containers);
            };
          };
        };
      };
    };

    ##

    system.activationScripts = {
      nfsDirectory.text = ''
        if [ ! -d /nfs ]
        then
          mkdir /nfs
          chown nobody:nogroup /nfs
        fi
      '';
      nfsProvisioner.text = ''
        if [ ! -d /var/lib/rancher/k3s/server/manifests ]
        then
          mkdir -p /var/lib/rancher/k3s/server/manifests
          chmod 700 /var/lib/rancher/k3s/server
        fi
        cp -f ${./manifests}/*.yaml /var/lib/rancher/k3s/server/manifests/
        chmod 600 /var/lib/rancher/k3s/server/manifests/*.yaml
      '';
    };

    ##

    virtualisation = {
      diskSize = 5 * 1024;
      # NOTE: $ROOT is defined in makefile
      # this is because qemu runner changing it's working directory to temporary
      sharedDirectories.host = { source = "$ROOT";  target = "/mnt/host"; };
    };

    ##

    boot.growPartition = true;
    boot.kernelParams = ["console=ttyS0"];
    boot.loader.grub.device = "/dev/vda";
    boot.loader.timeout = 0;

    nixpkgs = {
      overlays = [
        (self: super: let
          load = pkg: self.callPackage pkg { inherit self super; };
        in {
          unregistry = load unregistry;
        })
      ];
      config.allowUnfree = true;
    };
  };
}
