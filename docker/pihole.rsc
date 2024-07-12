######################################### Creating veth ##########################################
/interface veth
:if ([:len [find name~"pihole"]] = 0) do={
  add address=172.17.0.2/24 gateway=172.17.0.1 gateway6="" name=docker-pihole-veth  
}

/interface bridge
:if ([:len [find name=docker]] = 0) do={
  add name=docker
}

/ip address
:if ([:len [find interface=docker]] = 0) do={
  add address=172.17.0.1/24 interface=docker network=172.17.0.0  
}

/interface bridge port
:if ([:len [find bridge=docker interface~"pihole"]] = 0) do={
  add bridge=docker interface=docker-pihole-veth
}

######################################### Setting config #########################################
/container config
set layer-dir=usb1-part1/layer registry-url=https://registry-1.docker.io tmpdir=usb1-part1/pull

########################################## Creating envs #########################################
:global piholePassword
/container envs

:if ([:len [find key=TZ name=pihole_envs]] = 0) do={
  add key=TZ name=pihole_envs value=America/Los_Angeles
}
:if ([:len [find key=WEBPASSWORD name=pihole_envs]] = 0) do={
  add key=WEBPASSWORD name=pihole_envs value=$piholePassword
}
:if ([:len [find key=DNSMASQ_LISTENING name=pihole_envs]] = 0) do={
  add key=DNSMASQ_LISTENING name=pihole_envs value=all
}

######################################## Creating mounts #########################################
/container mounts

:if ([:len [find name=pihole_etc]] = 0) do={
  add dst=/etc/pihole name=pihole_etc src=/usb1-part1/pihole/mounts/etc  
}
:if ([:len [find name=pihole_dnsmasq]] = 0) do={
  add dst=/etc/dnsmasq.d name=pihole_dnsmasq src=/usb1-part1/pihole/mounts/etc_dnsmasq_d
}

###################################### Creating container #######################################
/container
add remote-image=pihole/pihole:latest envlist=pihole_envs interface=docker-pihole-veth mounts=pihole_etc,pihole_dnsmasq root-dir=usb1-part1/pihole start-on-boot=yes
