# Container Tools for Mavericks

docker, docker compose, docker-machine, and lazydocker for OS X 10.9. The daemon
runs in a Linux VM (VMware Fusion 8); docker-machine manages it.

## Setup

Install VMware Fusion, then create the VM and wire your shell to it:

```sh
docker-machine create -d vmwarefusion \
  --vmwarefusion-boot2docker-url /usr/local/share/modernmavericks/container-tools/boot2docker.iso \
  default \
&& if ! grep -q DOCKER ~/.bash_profile 2>/dev/null; then \
     printf '\neval "$(docker-machine env default)"\n' >> ~/.bash_profile; fi \
&& eval "$(docker-machine env default)"
```

From then on the VM starts automatically at login. To stop that:

```sh
launchctl unload -w /Library/LaunchAgents/dev.modernmavericks.container-tools-machine.plist
```

docker, docker compose, and lazydocker then work normally. `docked IMAGE CMD`
runs a container with `$PWD` at `/work/`.

## Updates

The package updates itself, and after each update offers to roll your VM host(s)
onto the new image — nothing to run by hand.

## Notes

- The VM is named "default" in VMware Fusion; adjust CPU/RAM in its Settings.
- boot2docker.iso: https://github.com/dragonflylee/boot2docker/
