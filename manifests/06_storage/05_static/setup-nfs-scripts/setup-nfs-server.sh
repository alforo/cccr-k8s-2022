#!/bin/bash
echo "===Configure NFS Server START==="
sudo apt install -y nfs-kernel-server
sudo mkdir /srv/nfs-volume
echo "/srv/nfs-volume *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports
echo "hello NFS volume" | sudo tee /srv/nfs-volume/index.html
sudo exportfs -arv
echo "===Configure NFS Server DONE==="
