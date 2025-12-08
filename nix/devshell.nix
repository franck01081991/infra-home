{ pkgs }:

pkgs.mkShell {
  name = "infra-home";
  packages = with pkgs; [
    age
    fluxcd
    kustomize
    helm
    kubeconform
    kubectl
    nixpkgs-lint
    nixfmt-rfc-style
    shellcheck
    trufflehog
    yamllint
  ];
}
