{ pkgs }:

pkgs.mkShell {
  name = "infra-home";
  packages = with pkgs; [
    age
    fluxcd
    helm
    kubeconform
    kubectl
    kustomize
    nixfmt-rfc-style
    shellcheck
    trufflehog
    yamllint
  ];
}
