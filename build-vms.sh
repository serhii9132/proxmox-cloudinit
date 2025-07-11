#!/bin/bash

TEMPLATE_VMID=100
BASE_VM_NAME="debian-vm"
START_VMID=1001

START_IP_PREFIX="192.168.0."
START_IP_HOST_PART=61
NETWORK_CIDR="/24"
GATEWAY_IP="192.168.0.1"

handle_error() {
    echo "Error: $1" >&2
    exit 1
}

deploy_vm() {
    local vm_number=$1
    local current_vmid=$((START_VMID + vm_number - 1))
    local vm_name="${BASE_VM_NAME}-${current_vmid}"

    # Calculate the IP address for this VM.
    local current_ip_host_part=$((START_IP_HOST_PART + vm_number - 1))
    local vm_ip="${START_IP_PREFIX}${current_ip_host_part}${NETWORK_CIDR}"

    echo "--- Deploying VM ${vm_number} (ID: ${current_vmid}, Name: ${vm_name}, IP: ${vm_ip}) ---"

    echo "Cloning template ${TEMPLATE_VMID} to ${current_vmid}..."
    qm clone "${TEMPLATE_VMID}" "${current_vmid}" --name "${vm_name}" || handle_error "Failed to clone VM template."

    # Configure Cloud-Init network settings.
    echo "Setting Cloud-Init network configuration for VM ${current_vmid}..."
    qm set "${current_vmid}" --ipconfig0 "ip=${vm_ip},gw=${GATEWAY_IP}" || handle_error "Failed to set Cloud-Init IP configuration."

    qm disk resize "${current_vmid}" scsi0 +17G

    # Start the VM.
    echo "Starting VM ${current_vmid}..."
    qm start "${current_vmid}" || handle_error "Failed to start VM."
}

main() {
    # Check if the template exists.
    if ! qm status "${TEMPLATE_VMID}" &>/dev/null; then
        handle_error "Template VM with ID ${TEMPLATE_VMID} does not exist. Run build-template.sh first."
    fi

    read -p "Enter the number of VMs to deploy (1-3): " num_vms

    if ! [[ "$num_vms" =~ ^[1-3]$ ]]; then
        handle_error "Invalid input. Enter a number between 1 and 3."
    fi

    echo "Deploying ${num_vms} virtual machine(s)..."

    for i in $(seq 1 "${num_vms}"); do
        deploy_vm "${i}"
    done
}

main