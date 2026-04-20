package docker

default allow := false

allow if input.local
allow if {
    input.image.host in ["docker.io", "ghcr.io"]
    input.image.hasProvenance
}

is_xx if input.image.repo == "tonistiigi/xx"
is_xx_valid if {
  is_xx
  docker_github_builder_tag(input.image, input.image.repo, sprintf("v%s", [input.image.tag]))
}
deny if is_xx_valid

decision := {"allow": allow}
