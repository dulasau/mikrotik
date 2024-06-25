:global dockerBridgeName "docker"
:global dockerIntName "veth-docker"
:global dockerBridgeAddr "172.17.0.1/24"
:global dockerIntAddr "172.17.0.2/24"
:global dockerIntGW "172.17.0.1"

:global usbPartition "usb1-part1"
:global dockerRootDir "$usbPartition/docker"
:global dockerPullDir "$dockerRootDir/pull"
:global dockerLayerDir "$dockerRootDir/layer"
:global dockerHubUrl "https://registry-1.docker.io"

:global dockerSetup do={
  :global dockerBridgeName
  :global dockerIntName
  :global dockerBridgeAddr
  :global dockerIntAddr
  :global dockerIntGW

  :global usbPartition
  :global dockerRootDir
  :global dockerPullDir
  :global dockerLayerDir
  :global dockerHubUrl

  :global dockerCleanup


  # Cleanup
  :put "Cleanup first!!!"
  $dockerCleanup

  # Creating docker veth interface
  :put "Creating veth $dockerIntName..."
  /interface/veth/add name=$dockerIntName address=$dockerIntAddr gateway=$dockerIntGW

  # Creating docker bridge
  :put "Creating docker bridge"
  /interface/bridge/add name=$dockerBridgeName

  :put "Settings IP address"
  /ip/address add interface=$dockerBridgeName address=$dockerBridgeAddr

  :put "Adding $dockerIntName interface to $dockerBridgeName bridge"
  /interface/bridge/port add bridge=$dockerBridgeName interface=$dockerIntName

  :put "Adding $dockerIntName to LAN list"
  /interface/list/member/add interface=$dockerIntName list=LAN

  # Setting containers configuration
  :put "Setting containers configuration"
  /container/config/set registry-url=$dockerHubUrl tmpdir=$dockerPullDir layer-dir=$dockerLayerDir

}

:global dockerCleanup do={
  :global dockerBridgeName
  :global dockerIntName
  :global dockerBridgeAddr
  :global dockerIntAddr
  :global dockerIntGW


  # Deleting docker bridge ip address
  /ip/address/remove [find interface=$dockerBridgeName]

  # Deleting docker bridge ports
  /interface/bridge/port/remove [find bridge=$dockerBridgeName]

  # Deleting docker bridge
  /interface/bridge/remove [find name=$dockerBridgeName]

  # Deleting LAN list member
  /interface/list/member/remove [find interface=$dockerIntName]

  # Deleting docker veth
  /interface/veth/remove [find name=$dockerIntName]

}


:global dockerCreate do={
  :global dockerRootDir
  :global dockerIntName

  # Creating Debian container
  :local containerName debian
  /container/add remote-image=debian:latest cmd="tail -F /dev/null" root-dir="$dockerRootDir/$containerName" hostname="$containerName.netlab.dzmcloud.com" logging=yes interface=$dockerIntName
}
