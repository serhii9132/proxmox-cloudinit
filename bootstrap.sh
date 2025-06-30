#!/bin/bash

IMAGENAME="debian-12-generic-amd64.qcow2"
IMAGEURL="https://cdimage.debian.org/images/cloud/bookworm/latest/"
DOWNLOAD_DIR="/tmp"

STORAGE="local"
VMNAME="debian-12-template"
VMID=100
MEMORY=2048
CORES=2

VMSETTINGS_BASE="--net0 virtio,bridge=vmbr0 --ostype l26"
VM_IP_CONFIG="--ipconfig0=ip=192.168.0.61/24,gw=192.168.0.1"

download_image() {
    local full_image_path="${DOWNLOAD_DIR}/${IMAGENAME}"
    echo "Downloading image ${IMAGENAME}..."
    wget -O "${full_image_path}" --continue "${IMAGEURL}/${IMAGENAME}"
}

create_vm() {
    echo "Creating VM with ID ${VMID} and name ${VMNAME}..."
    qm create "${VMID}" --name "${VMNAME}" --memory "${MEMORY}" --cores "${CORES}" ${VMSETTINGS_BASE}
}

import_disk() {
    local full_image_path="${DOWNLOAD_DIR}/${IMAGENAME}"
    echo "Importing disk ${full_image_path} to storage ${STORAGE} for VM ${VMID}..."
    qm importdisk "${VMID}" "${full_image_path}" "${STORAGE}" --format qcow2
}

configure_vm_disks_and_cloudinit() {
    local disk_path=$(qm config "${VMID}" | grep "unused0" | awk '{print $2}' | sed 's/,.*//')
    if [ -z "$disk_path" ]; then
        handle_error "Could not find path to imported disk."
    fi

    echo "Configuring disks and Cloud-Init for VM ${VMID}..."
    qm set "${VMID}" "${VM_IP_CONFIG}"
    qm set "${VMID}" --scsihw virtio-scsi-pci --scsi0 "${disk_path}"
    qm set ${VMID} --ide2 ${STORAGE}:cloudinit --agent 1
    qm set ${VMID} --cicustom "user=${STORAGE}:snippets/user-data.yaml"
    qm set "${VMID}" --boot c --bootdisk scsi0
    qm set "${VMID}" --serial0 socket
}

create_template() {
    echo "Creating template from VM ${VMID}..."
    qm template "${VMID}"
}

cleanup() {
    echo "Removing temporary image ${DOWNLOAD_DIR}/${IMAGENAME}..."
    rm -f "${DOWNLOAD_DIR}/${IMAGENAME}"
}

main() {
    download_image
    create_vm
    import_disk
    configure_vm_disks_and_cloudinit
    create_template
    cleanup
}

main