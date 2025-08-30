#!/bin/sh

apk update
apk add curl

curl -sfL https://get.k3s.io | sh -s - server

rc-update add k3s default
rc-service k3s start

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

sleep 30

/vagrant/scripts/create-configmaps.sh

kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml