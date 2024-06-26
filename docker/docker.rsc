###############################################
########### Docker Helper Scripts #############
###############################################
:global printMsgMaxLen 100

:global dockerInfo {
  "bridgeName"="docker";
  "bridgeIp"=172.17.0.1/24;
  "vethGateway"=172.17.0.1;
  "vethPostfix"="docker-veth";
  "domainName"="docker.test.com";
  "usbDriveName"="usb1";
  "usbPartition"="docker-storage";
  "rootDir"="docker";
  "pullDir"="pull";
  "layerDir"="layer";
  "hubUrl"="https://registry-1.docker.io";
  "supportedContainers"={"pihole";"proxy";"debian"};
  "containerIps"={
    "pihole"=172.17.0.2/24;
    "proxy"=172.17.0.3/24;
    "debian"=172.17.0.4/24;
  };
}

:global dockerSetup do={
  :global dockerInfo

  :global dockerCleanup
  :global printMsg

  # Validations
  :if ([:len [/system/package/find name=container]] = 0) do={
    $printMsg "container package is not installed, install it first!"
    :return ""
  }

  :if ([:len [/disk/find type=hardware slot=($dockerInfo->"usbDriveName")]] = 0) do={
    $printMsg "USB drive is not installed, please insert USB drive!"
    :return ""
  }

  # Cleanup
  $printMsg "Cleanup first!!!"
  $dockerCleanup

  # Create docker usb partition
  :if ([:len [/disk/find slot=($dockerInfo->"usbPartition")]] = 0) do={
    $printMsg ("Creating ".($dockerInfo->"usbPartition")." partition")
    /disk/add parent=usb1 slot=($dockerInfo->"usbPartition") type=partition

    $printMsg ("Formatting ".($dockerInfo->"usbPartition")." partition to ext4")
    /disk/format-drive ($dockerInfo->"usbPartition") file-system=ext4    
    
    $printMsg "Done"
  } else={
    $printMsg ("Partition ".($dockerInfo->"usbPartition")." already exists!")
  }

  # Format docker usb partition. Checking just in case!
  if ([/disk/get [find slot=($dockerInfo->"usbPartition")] fs] != "ext4") do={
    $printMsg ("Formatting ".($dockerInfo->"usbPartition")." partition to ext4")
    /disk/format-drive ($dockerInfo->"usbPartition") file-system=ext4
    $printMsg "Done"
  }

  # Creating docker bridge
  $printMsg "Creating docker bridge..."
  /interface/bridge/add name=($dockerInfo->"bridgeName")

  $printMsg "Setting bridge IP address..."
  /ip/address add interface=($dockerInfo->"bridgeName") address=($dockerInfo->"bridgeIp")

  $printMsg ("Adding ".($dockerInfo->"bridgeName")." to LAN list")
  /interface/list/member/add interface=($dockerInfo->"bridgeName") list=LAN

  # Setting containers configuration
  $printMsg "Setting containers configuration"
  :local pullDir (($dockerInfo->"usbPartition")."/".($dockerInfo->"rootDir")."/".($dockerInfo->"pullDir"))
  :local layerDir (($dockerInfo->"usbPartition")."/".($dockerInfo->"rootDir")."/".($dockerInfo->"layerDir"))
  /container/config/set registry-url=($dockerInfo->"hubUrl") tmpdir=$pullDir layer-dir=$layerDir
}

:global dockerCleanup do={
  :global dockerInfo
  :global printMsg

  # Stoping all containers
  $printMsg "Stoping containers..."
  :if ([:len [/container/find status=running]] > 0) do={
     /container/stop [find status=running]
  }
  :do {} while ([:len [/container/find status=stopping]] > 0)
  $printMsg "All containers stopped!"

  # Remove containers
  $printMsg "Removinng containers"
  /container/remove [find]

  # Deleting docker bridge ip address
  $printMsg "Cleanup bridge ip address..."
  /ip/address/remove [find interface=($dockerInfo->"bridgeName")]

  # Deleting docker bridge ports
  /interface/bridge/port/remove [find bridge=($dockerInfo->"bridgeName")]

  # Deleting docker bridge
  /interface/bridge/remove [find name=($dockerInfo->"bridgeName")]

  # Deleting LAN list member
  /interface/list/member/remove [find interface=($dockerInfo->"bridgeName")]
}

:global dockerCreateContainer do={
  :global dockerInfo
  :global dockerCreateVeth
  :global printMsg
  :local hostname ("$name.".($dockerInfo->"domainName"))

  :if ([:typeof $name] != "str" || [:len $name] = 0) do={
    $printMsg "Please specify image: debian, pihole or proxy"
    :return ""
  }

  # Validation
  :if ([/container/find hostname=$hostname]) do={
    $printMsg ("Container with hostname $hostname already exists!")
    :return ""
  }  

  # Creating veth
  :local vethName [$dockerCreateVeth name=$name]
  :local rootDir (($dockerInfo->"usbPartition")."/".($dockerInfo->"rootDir")."/$name")

  :if ($name = "pihole") do={
    # Add env variables
    /container/envs/add name=pihole_envs key=TZ value=america/los_angeles
    /container/envs/add name=pihole_envs key=WEBPASSWORD value=password123

    # Add mounts
    /container/mounts/add name=etc_pihole src="$rootDir/mounts/etc" dst=/etc/pihole
    /container/mounts/add name=dnsmasq_pihole src="$rootDir/mounts/dnsmasq" dst=/etc/dnsmasq.d

    # Creating container
    /container/add remote-image=pihole/pihole:latest root-dir=$rootDir hostname=$hostname interface=$vethName mounts=etc_pihole,dnsmasq_pihole envlist=pihole_envs logging=yes
  }

  $printMsg "Extracting container image..."
  :do {} while ([/container/get [find hostname=$hostname] status] = "extracting")

  $printMsg "Starting container..."
  /container/start [find hostname=$hostname]

  $printMsg "Done, container details:"
  /container/print detail where hostname=$hostname
}

:global dockerDeleteContainer do={
  :global dockerInfo
  :global dockerDeleteVeth
  :global printMsg
  :local hostname ("$name.".($dockerInfo->"domainName"))

  # Validation
  :if ([:typeof $name] != "str" || [:len $name] = 0) do={
    $printMsg "Please specify image: debian, pihole or proxy"
    :return ""
  }

  :if ([:len [/container/find hostname=$hostname]] = 0) do={
    $printMsg ("Container with hostname $hostname does not exist!")
    :return ""
  }

  # Stopping container
  $printMsg "Stopping container..."
  /container/stop [find hostname=$hostname]
  :do {} while ([/container/get [find hostname=$hostname] status] != "stopped")
  $printMsg "Done"

  # Deleting container
  $printMsg "Deleting container"
  /container/remove [find hostname=$hostname]

  :if ($name = "pihole") do={
    $printMsg "Deleting mounts and envs"
    # Delete env variables
    /container/envs/remove [find name=pihole_envs]
    # Delete mounts
    /container/mounts/remove [find name~"pihole"]
  }

  # Deleting veth
  $printMsg "Deleting veth"
  $dockerDeleteVeth name=$name
}

:global dockerCreateVeth do={
  :global dockerInfo
  :global printMsg
  :local vethName (($dockerInfo->"vethPostfix")."-$name")

  # Creating docker veth interface
  $printMsg ("Creating veth $vethName")
  /interface/veth/add name=$vethName address=($dockerInfo->"containerIps"->"$name") gateway=($dockerInfo->"vethGateway")
  
  # Adding veth to the bridge
  $printMsg ("Adding $vethName interface to ".($dockerInfo->"bridgeName")." bridge")
  /interface/bridge/port add bridge=($dockerInfo->"bridgeName") interface=$vethName

  :return $vethName
}

:global dockerDeleteVeth do={
  :global dockerInfo
  :global printMsg
  :local vethName (($dockerInfo->"vethPostfix")."-$name")

  # Removing veth from the bridge
  $printMsg ("Removing $vethName interface from ".($dockerInfo->"bridgeName")." bridge")
  /interface/bridge/port/remove [find interface=$vethName]

  # Creating docker veth interface
  $printMsg ("Deleting veth $vethName...")
  /interface/veth/remove [find name=$vethName]

  :return $vethName
}

:global printMsg do={
  :global printMsgMaxLen
  :local strLen [:len $1]
  :local fillInsLen (($printMsgMaxLen - $strLen) / 2 - 2)
  :local fillIn
  :local result

  for i from=1 to=$fillInsLen do={
    :set fillIn "$fillIn#"
  }
  :set result "$fillIn $1 $fillIn"
  :if ($strLen % 2 > 0) do={ :set result "$result#" }
  :put "$result\r\n"
}
