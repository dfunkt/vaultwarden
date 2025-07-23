all:
	./render_template Dockerfile.j2 '{"base": "debian"}' > Dockerfile.debian
	./render_template Dockerfile.j2 '{"base": "alpine"}' > Dockerfile.alpine
	./render_template Dockerfile.j2 '{"base": "scratch"}' > Dockerfile.scratch
.PHONY: all
