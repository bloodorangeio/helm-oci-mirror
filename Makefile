.PHONY: build
build:
	go mod vendor && CGO_ENABLED=0 go build -o bin/oci-mirror .../cmd/oci-mirror/.

.PHONY: acceptance
acceptance: build
	./scripts/acceptance.sh

.PHONY: clean
clean:
	rm -rf bin/ testdata/ .venv/ .robot/ vendor/
	docker images | grep local-chartmuseum | awk '{print $$3}' | xargs docker rmi -f || true
	docker images | grep local-zot | awk '{print $$3}' | xargs docker rmi -f || true

.PHONY: install
install: build
	HELM_OCI_MIRROR_PLUGIN_NO_INSTALL_HOOK=1 helm plugin install $(shell pwd)

.PHONY: uninstall
uninstall:
	helm plugin remove oci-mirror
