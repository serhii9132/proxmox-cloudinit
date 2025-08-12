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

configure_disks() {
    local disk_path=$(qm config "${VMID}" | grep "unused0" | awk '{print $2}' | sed 's/,.*//')
    if [ -z "$disk_path" ]; then
        handle_error "Could not find path to imported disk."
    fi

    echo "Configuring disks for VM ${VMID}..."
    qm set "${VMID}" --scsihw virtio-scsi-pci --scsi0 "${disk_path}"
    qm set "${VMID}" --boot c --bootdisk scsi0
    qm set "${VMID}" --serial0 socket
}

configure_cloudinit() {
    if [ -f .env ]; then
        source .env
    else
        echo ".env file doesn't exists"
        exit 1 
    fi

    local path_to_snippet="/var/lib/vz/snippets"
    local file="user-data.yaml"

    echo "Configuring Cloudinit for VM ${VMID}..."

    cat <<-EOF >"${path_to_snippet}/${file}"
#cloud-config
hostname: debian
manage_etc_hosts: true

package_update: true
package_upgrade: true
packages:
- qemu-guest-agent

timezone: Europe/Kyiv

chpasswd:
  expire: false
  users:
  - {name: root, password: $HASH_ROOT_PASS}

runcmd:
- sed -i 's/[#]*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
- sed -i 's/[#]*PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
- systemctl reload ssh
- systemctl enable qemu-guest-agent
- systemctl start qemu-guest-agent
EOF

    qm set ${VMID} --ide2 ${STORAGE}:cloudinit --agent 1
    qm set ${VMID} --cicustom "user=${STORAGE}:snippets/user-data.yaml"
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
    configure_disks
    configure_cloudinit
    create_template
    cleanup
}

main