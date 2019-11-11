# I referred the guestbook application and microservices
# to find out how those are initialized.
# gcloud config set project [PROJECT_ID]
# Maheshs-MBP-2:Translator-k8s maheshrajannan$ gcloud config get-value project
# redis-251601
# gcloud config set compute/zone [COMPUTE_ENGINE_ZONE]
# https://cloud.google.com/kubernetes-engine/docs/tutorials/guestbook
echo '1/20: Is glcoud initialized'
# Set node environment early so that it fails quickly.
source ~/.bash_profile
echo '2/20: Reset Docker to prevent connection error'
unset DOCKER_HOST
unset DOCKER_TLS_VERIFY
unset DOCKER_TLS_PATH
docker ps
which nvm
nvm use 12.13.0
sh deleteGCloudCluster.sh
# If you create more than 1 node and you exceed the limit,
# you have to wait 2 days for increasing or decreasing the limit..
# oh poor DEVOPS engineer..!
gcloud container clusters create translator3 --num-nodes=1

CURRENT_DATE=`date +%b-%d-%y_%I_%M_%p`
echo "Starting At "$CURRENT_DATE
kubectl get deployments
#INFO: there may not be a need to delete.
kubectl delete deployment translator-frontend
kubectl delete deployment sa-logic
kubectl delete deployment sa-web-app
kubectl get deployments

kubectl get services
kubectl delete service translator-frontend-lb
kubectl delete service sa-logic
kubectl delete service sa-web-app-lb
kubectl get services

kubectl apply -f resource-manifests/sa-logic-deployment.yaml --record
kubectl get deployments
kubectl get pods

kubectl apply -f resource-manifests/service-sa-logic.yaml --record
kubectl get services
kubectl get pods

kubectl apply -f resource-manifests/sa-web-app-deployment.yaml --record
kubectl get deployments
kubectl get pods

kubectl apply -f resource-manifests/service-sa-web-app-lb.yaml
kubectl get services
kubectl get pods

newIp=""
newPort=""
while [ -z $newIp ]; do
    sleep 1
    newIp=`kubectl get service sa-web-app-lb --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'`
	newPort=`kubectl get service sa-web-app-lb --output=jsonpath='{.spec.ports[0].port}'`
done

echo "newIp "$newIp
echo "newPort "$newPort
new_values="$newIp:$newPort"
old_values=`cat oldValues.txt`
echo "Old Values Are "$old_values
echo "New Values Are "$new_values
echo $new_values > oldValues.txt

cd translator-frontend
echo "Replacing time"
sed -ie 's/mode/gCloudK8s/g' public/index.html
sed -ie 's/current_time/'$CURRENT_DATE'/g' public/index.html
cat public/index.html
echo "Running build"

echo "Replacing-"$old_values"-with-"$new_values"-src/App.js"
sed -ie 's/'$old_values'/'$new_values'/g' src/App.js
cat src/App.js

rm -fr node_modules

npm install

npm run build

docker build -f Dockerfile -t $DOCKER_USER_ID/translator-frontend:minikube .
docker push $DOCKER_USER_ID/translator-frontend:minikube

sed -ie 's/gCloudK8s/mode/g' public/index.html
echo "Restoring :"$CURRENT_DATE" With current_time"
sed -ie 's/'$CURRENT_DATE'/current_time/g' public/index.html
cat public/index.html

cd ../
kubectl apply -f resource-manifests/translator-frontend-deployment.yaml
kubectl get pods
kubectl get svc

kubectl get pods
kubectl create -f resource-manifests/service-translator-frontend-lb.yaml
kubectl get svc
