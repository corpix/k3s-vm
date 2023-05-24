let nixpkgs = <nixpkgs>;
    config = {};
in with import nixpkgs { inherit config; }; let
  shellWrapper = writeScript "shell-wrapper" ''
    #! ${stdenv.shell}
    set -e

    exec -a shell ${fish}/bin/fish --login --interactive "$@"
  '';
in stdenv.mkDerivation rec {
  name = "nix-shell";
  buildInputs = [
    hivemind
    kubectl
    k9s
    kubernetes-helm
  ];
  shellHook = ''
    export LANG="en_US.UTF-8"
    export NIX_PATH="nixpkgs=${nixpkgs}"
    export KUBECONFIG=$(pwd)/.kubeconfig

    if [ ! -z "$PS1" ]
    then
      export SHELL="${shellWrapper}"
      exec "$SHELL"
    fi
  '';
}
