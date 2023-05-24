.ONESHELL:

ssh ?= ssh
ssh_args ?=
ssh_cmd = $(ssh) \
		-o ControlMaster=no \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-p 2222

export ROOT = $(PWD)

.PHONY: build
build:
	nix-build '<nixpkgs/nixos>' --show-trace \
		-A vm \
		-I nixos-config=./configuration.nix

.PHONY: realise
realise:
	nix-store --show-trace --realise \
		$(shell nix-instantiate --show-trace \
			--arg configuration ./configuration.nix \
			./wrapper.nix)

.PHONY: qemu
qemu: build
	export QEMU_OPTS="$(QEMU_OPTS) -nographic -serial mon:stdio"
	export QEMU_KERNEL_PARAMS="$(QEMU_KERNEL_PARAMS) console=ttyS0"
	export QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:6443-:6443"
	exec ./result/bin/run-nixos-vm -m 2048

.PHONY: ssh
ssh:
	$(ssh_cmd) root@127.0.0.1 $(ssh_args)

.PHONY: manifests
manifests:
	rsync -e "$(ssh_cmd)" -avz manifests/ root@127.0.0.1:/var/lib/rancher/k3s/server/manifests/

.PHONY: k9s
k9s:
	$(MAKE) ssh ssh=ssh ssh_args="cat /etc/rancher/k3s/k3s.yaml > .kubeconfig"
	k9s --kubeconfig=.kubeconfig
