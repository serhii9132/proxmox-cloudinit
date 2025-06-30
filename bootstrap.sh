#!/bin/bash

IMAGENAME="debian-12-generic-amd64.qcow2"
IMAGEURL="https://cdimage.debian.org/images/cloud/bookworm/latest/"
DOWNLOAD_DIR="/tmp"

STORAGE="storage"
VMNAME="debian-12-template"
VMID=100
MEMORY=2048
CORES=2
VMSETTINGS="--net0 virtio,bridge=vmbr0 --agent 1 --ostype l26"

wget -O ${DOWNLOAD_DIR}/${IMAGENAME} --continue ${IMAGEURL}/${IMAGENAME}
qm create ${VMID} --name ${VMNAME} --memory ${MEMORY} --core ${CORES} ${VMSETTINGS}
qm importdisk ${VMID} ${DOWNLOAD_DIR}/${IMAGENAME} ${STORAGE} --format qcow2
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:${VMID}/vm-${VMID}-disk-0.qcow2
qm set ${VMID} --ide2 ${STORAGE}:cloudinit
qm set ${VMID} --ipconfig0=ip=192.168.0.61/24,gw=192.168.0.1
qm set 100 --cicustom "user=storage:snippets/user-data.yaml"
qm set ${VMID} --boot c --bootdisk scsi0
qm set ${VMID} --serial0 socket
qm template ${VMID}

rm ${DOWNLOAD_DIR}/${IMAGENAME}