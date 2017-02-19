# actualización del sistema
# sudo apt update && sudo apt upgrade -y

# instalamos docker
echo "Instalando docker engine"
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-engine jq
sudo usermod -aG docker ${USER}
(newgrp docker)&
sudo systemctl restart docker

echo "Instalando kubectl"
# instalación de kubectl
# curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Instalación de minikube
echo "Instalando minikube"
# curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.16.0/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/

# Instalación del driver kvm (from https://github.com/kubernetes/minikube/blob/v0.16.0/DRIVERS.md#kvm-driver)
# sudo curl -L https://github.com/dhiltgen/docker-machine-kvm/releases/download/v0.7.0/docker-machine-driver-kvm -o /usr/local/bin/docker-machine-driver-kvm
# sudo chmod +x /usr/local/bin/docker-machine-driver-kvm
# sudo apt install libvirt-bin qemu-kvm
# Add yourself to the libvirtd group (use libvirt group for rpm based distros) so you don't need to sudo
# sudo usermod -a -G libvirt $(whoami)
# Update your current session for the group change to take effect
# (newgrp libvirt)&

# iniciar minikube
minikube start --vm-driver=kvm

# establecemos secret para base de datos
kubectl create secret generic mysql-secret --from-literal=mypass=L2e@v48GNVFT87b1

# editar yaml y crear kube
# EXTERNAL_IP=${minikube ip}
# -e "s/@EDITAR_EXTERNAL_IP@/${EXTERNAL_IP}/"
sed -e "s/@EDITAR_USUARIO@/${USER}/" php-mysql-rc.tmpl.yaml > /tmp/php-mysql-rc-${USER}.yaml || exit 1
kubectl create -f /tmp/php-mysql-rc-${USER}.yaml

# mostrarmos la URL del recurso
IP=$(kubectl get svc php-mysql-svc-${USER} -o json|jq -r .spec.clusterIP)
echo "Para acceder a la aplicación visite: http://${IP:?}/php-mysql/"

echo "Luego, para eliminarla haga:"
echo "kubectl delete svc php-mysql-svc-${USER}"
echo "kubectl delete rc php-mysql-rc-${USER}"
