#!/bin/sh

kubectl create configmap app-one-config --from-file=index.html=/vagrant/confs/src/app1.html --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap app-two-config --from-file=index.html=/vagrant/confs/src/app2.html --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap app-three-config --from-file=index.html=/vagrant/confs/src/app3.html --dry-run=client -o yaml | kubectl apply -f -