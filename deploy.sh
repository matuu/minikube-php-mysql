# actualización del sistema
sudo apt update && sudo apt upgrade -y

# instalamos docker
echo "Instalando docker engine"
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-engine
sudo usermod -aG docker ${USER}
(newgrp docker)&
sudo systemctl restart docker

# instalación de kubectl
echo "Instalando kubectl"
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Instalación de minikube
echo "Instalando minikube"
curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.16.0/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/

echo "Instalando driver kvm"
# Instalación del driver kvm (from https://github.com/kubernetes/minikube/blob/v0.16.0/DRIVERS.md#kvm-driver)
curl -Lo docker-machine-driver-kvm https://github.com/dhiltgen/docker-machine-kvm/releases/download/v0.7.0/docker-machine-driver-kvm
sudo mv docker-machine-driver-kvm /usr/local/bin/docker-machine-driver-kvm
sudo chmod +x /usr/local/bin/docker-machine-driver-kvm
sudo apt install libvirt-bin qemu-kvm
# Add yourself to the libvirtd group (use libvirt group for rpm based distros) so you don't need to sudo
sudo usermod -a -G libvirt $(whoami)
# Update your current session for the group change to take effect
(newgrp libvirt)&

: ${registry:="localhost:5000"}

# iniciar minikube
minikube start --vm-driver=kvm --insecure-registry ${registry}
# Using minikube's Docker daemon from our localhost
eval $(minikube docker-env)

# esperar a que account service esté ok
while [ "$( kubectl get serviceaccount|awk '/default/')" == "" ]
do
  sleep 1
done

# iniciando un registry local dentro del cluster
kubectl apply -f local-registry.yml

# crear imágenes docker
cd php-mysql-docker
(test -d php-mysql || git clone https://github.com/IBM-Bluemix/php-mysql.git)
# construir imagen docker
APP_TAGS=php-mysql-${USER}:latest
docker build -t ${APP_TAGS} .
docker tag ${APP_TAGS} ${registry}/${APP_TAGS}
cd ..

# esperamos a que termine de levantar el registry
STATUS_REGISTRY=$(kubectl get pod --namespace kube-system|awk '/kube-registry-proxy/{ print $3}')
echo "Estado (kube-registry-proxy): ${STATUS_REGISTRY}"
while [ "$STATUS_REGISTRY" != "Running" ]
do
  sleep 1
  STATUS_REGISTRY=$(kubectl get pod --namespace kube-system|awk '/kube-registry-proxy/{ print $3}')
  echo -en "\e[1A"; echo -e "\e[0KEstado (kube-registry-proxy): ${STATUS_REGISTRY}"
done
echo "OK."
# empujar a registry local
docker push ${registry}/${APP_TAGS}

# establecemos secret para base de datos
kubectl create secret generic mysql-secret --from-literal=mypass=L2e@v48GNVFT87b1

# editar yaml y crear kube
sed -e "s/@EDITAR_USUARIO@/${USER}/" -e "s/@EDITAR_REGISTRY@/${registry}/"  php-mysql-rc.tmpl.yaml > /tmp/php-mysql-rc-${USER}.yaml || exit 1
kubectl create -f /tmp/php-mysql-rc-${USER}.yaml

# esperamos a que esté corriendo
STATUS=$(kubectl get pod|awk '/php-mysql-rc/{ print $3 }')
echo "Estado (php-mysql-rc-${USER}): ${STATUS}"
while [ "$STATUS" != "Running" ]
do
      if [ "$STATUS" == "ImagePullBackOff" ]; then
          # intento subir nuevamente la imagen al registry local
          # aleatoriamente, al hacer push obtengo un error EOF
          docker push ${registry}/${APP_TAGS}
      fi
      sleep 1
      STATUS=$(kubectl get pod|awk '/php-mysql-rc/{ print $3 }')
      echo -en "\e[1A"; echo -e "\e[0KEstado (php-mysql-rc-${USER}): ${STATUS}"
done
echo "OK!"
# mostramos la URL del recurso
IP=$(minikube service php-mysql-svc-${USER} --url)
echo "Para acceder a la aplicación visite: ${IP:?}/php-mysql/"

echo "Luego, para eliminarla haga:"
echo "kubectl delete svc php-mysql-svc-${USER}"
echo "kubectl delete rc php-mysql-rc-${USER}"
