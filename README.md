# Mikrotik helper scripts

## Docker

### How to install

* Download extra packages from [https://mikrotik.com/download](https://mikrotik.com/download) for your specific architecture (arm/arm64)
* Extract files and find container-7.XX.XX-arm[64].npk
* Upload the npk to your router and reboot. [Mikrotik Packages](https://help.mikrotik.com/docs/display/ROS/Packages)
* Enable containers package ```/system/device-mode/update container=yes``` and follow reboot prompt
* Fetch the script ```/tool/fetch url=https://raw.githubusercontent.com/dulasau/mikrotik/main/docker/docker.rsc```
* Import the script ```/import docker.rsc```

### How to use

There are 3 main commands:
* ```$dockerSetup``` Makes all necessary configurations to use containers on your router (e.g. creating veth, bridge, configuration containers package, etc)
* ```$dockerCreate```
* ```$dockerCleanup```
