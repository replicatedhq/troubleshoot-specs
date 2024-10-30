#!/bin/bash
#
# This script collects pcap files from a Kubernetes host, a Flannel or Calico VXLAN interface, and a pod.
#
# This script must be run as root.
#
# Provide the namespace and name of a pod to collect from.  The script will inspect `ip route` to determine the interface name of a given Kubernetes pod and start a tcpdump process attached to that interface.  Then, another tcpdump process will be attached to either the Flannel or the Calico VXLAN interface, and finally, a tcpdump process will be attached to the primary interface of the host, filtering for VXLAN traffic.
#
# Usage:
#   ./tcpdump.sh <namespace> <pod-name> [time frame]
# namespace: string, required
# pod-name: string, required
# time frame: date/time string, optional; defaults to '5m'.  Example: 100s, 5m, 1h.

# depends on kubectl, jq, tcpdump, timeout, bash, iproute2, grep, awk, crictl

# TODO: error handling

readonly VXLAN_FLAGS="-lttttnnvv"

namespace=$1
pod=$2
timeframe="1m"

if [[ -z $namespace || -z $pod ]]; then
  echo "Usage: $0 <namespace> <pod-name>"
  exit 1
fi

if [[ -n  $3 ]]; then
  timeframe="$3"
fi

set -euo pipefail

# if not root, then exit
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

# check for required binaries
for binary in kubectl jq tcpdump; do
  if ! command -v "$binary" &> /dev/null; then
    echo "Could not find $binary"
    exit 1
  fi
done


function getCalicoInterface () {
  pod_name="$1"
  pod_namespace="$2"
  pod_ip=$(kubectl get pod "$pod_name" -n "$pod_namespace" -o json | jq -r '.status.podIP')
  # Get the interface name from routing table
  pod_interface=$(ip route | grep "$pod_ip" | awk '{print $3}')
  echo "$pod_interface"
}

function getFlannelInterface () {
  pod_name="$1"
  pod_namespace="$2"

  # check for crictl binary
  if ! command -v crictl &> /dev/null; then
    echo "Could not find crictl; please install it"
    exit 1
  fi

  # Figure out the pod's container PID
  container_id="$(crictl ps | grep "$pod_name" | awk 'NR==1{print $1}')"
  pid="$(crictl inspect "$container_id" | jq .info.pid)"

  # link to /var/run/netns so we can use ip netns easily
  mkdir -p /var/run/netns
  ln -sf "/proc/$pid/ns/net" "/var/run/netns/$pod_name"

  # Get the interface index of the container's eth0.
  # c_index is the index of the container's eth0, which should be in the form of eth0.if${h_index}
  # h_index is the index of the corresponding host veth interface from `ip link show type veth`
  local c_index h_index
  c_index=$(ip netns exec "$pod_name" ip link show type veth | head -n1 | awk '{print $2}' | sed 's/.*@if//')
  h_index=$(ip link show type veth | grep -E "^${c_index}" | awk '{print $2}' | sed 's/@.*//')

  # Clean up the netns symlink, since we don't need it anymore
  rm -f "/var/run/netns/${1}"

  echo "$h_index"
}

# Figure out if we're using Flannel or Calico VXLAN
if ip link show | grep flannel > /dev/null; then
  vxlan_interface=flannel.1
  vxlan_port=8472
  cni=flannel
elif ip link show | grep cali > /dev/null; then
  vxlan_interface=vxlan.calico
  vxlan_port=4789
  cni=calico
else
  echo "Could not determine VXLAN interface on host"
  exit 1
fi

if [[ $cni == "calico" ]]; then
  pod_interface=$(getCalicoInterface "$pod" "$namespace")
elif [[ $cni == "flannel" ]]; then
  pod_interface=$(getFlannelInterface "$pod" "$namespace")
else
  echo "Could not determine pod interface from namespace $namespace and pod $pod"
  exit 1
fi

# Collect tcpdump from the pod's interface
echo "Collecting tcpdump from pod $pod on interface $pod_interface"
timeout "$timeframe" tcpdump ${VXLAN_FLAGS} -i "$pod_interface" -w "$(hostname)-$pod-pod".pcap &

# Collect tcpdump from the VXLAN interface
echo "Collecting tcpdump from VXLAN interface $vxlan_interface on port $vxlan_port"
timeout "$timeframe" tcpdump ${VXLAN_FLAGS} -i "$vxlan_interface" -w "$(hostname)-$vxlan_interface".pcap &

if [[ $cni == "flannel" ]]; then
  # Collect tcpdump also from the cni0 bridge
  echo "Collecting tcpdump from cni0 bridge"
  timeout "$timeframe" tcpdump ${VXLAN_FLAGS} -i "cni0" -w "$(hostname)-cni0".pcap &
fi

# Figure out the host's primary interface
host_interface=$(ip route | grep '^default' | awk '{print $5}')
echo "Collecting tcpdump from host interface $host_interface"

# Collect tcpdump from the host's primary interface
timeout "$timeframe" tcpdump ${VXLAN_FLAGS} -i "$host_interface" -T vxlan port "$vxlan_port" -w "$(hostname)-$host_interface".pcap &

# Wait for all the tcpdump processes to finish
wait < <(jobs -p)

echo "Done collecting tcpdump files"
