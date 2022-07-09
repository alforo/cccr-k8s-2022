#!/bin/bash
ansible kube_node -i ~/kubespray/inventory/mycluster/inventory.ini -m apt -a 'name=nfs-common' --become
