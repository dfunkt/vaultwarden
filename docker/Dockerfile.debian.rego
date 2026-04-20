package docker

default allow := false

allow if input.local
allow if {
    input.image.host in ["docker.io", "ghcr.io"]
    input.image.hasProvenance
    not is_xx
}

is_xx if input.image.repo == "tonistiigi/xx"
is_xx_valid if {
  is_xx
  docker_github_builder(input.image, input.image.repo)
  some sig in input.image.signatures
  docker_github_builder_signature(sig, input.image.repo)
  # tag ref exists in some signature, even if input.image.tag is empty
  startswith(sig.signer.sourceRepositoryRef, "refs/tags/v")
}
allow if is_xx_valid

decision := {"allow": allow}
