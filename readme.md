## running

```
$ make qemu
nix-build '<nixpkgs/nixos>' --show-trace \
	-A vm \
	-I nixos-config=./configuration.nix

...

Booting from ROM...
Probing EDD (edd=off to disable)... oc[    0.514045] sgx: There are zero EPC sections.

<<< NixOS Stage 1 >>>

loading module virtio_balloon...
loading module virtio_console...
loading module virtio_rng...
loading module dm_mod...
running udev...
Starting systemd-udevd version 253.3
...

<<< NixOS Stage 2 >>>

...

[  OK  ] Started Name Service Cache Daemon (nsncd).
[  OK  ] Reached target Host and Network Name Lookups.
[  OK  ] Reached target User and Group Name Lookups.
         Starting NFS status monitor for NFSv2/3 locking....
[  OK  ] Started NFS status monitor for NFSv2/3 locking..


<<< Welcome to NixOS 23.05pre-git (x86_64) - ttyS0 >>>

Run 'nixos-help' for the NixOS manual.

nixos login:
```

Then you could:
- `make ssh` to SSH into
- `make manifests` to update manifests from `./manifests/` dir
- `make k9s` to run `k9s` TUI
