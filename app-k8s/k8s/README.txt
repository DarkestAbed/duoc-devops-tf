Despliegue tienda-perritos en EKS (namespace 'tienda')

1) Configurar kubectl contra tu cluster:
   aws eks update-kubeconfig --region us-east-1 --name <NOMBRE_TU_CLUSTER>

2) Aplicar namespace:
   kubectl apply -f namespace.yaml

3) Aplicar recursos de base de datos:
   kubectl apply -f mysql-secret.yaml
   kubectl apply -f mysql-deployment.yaml
   kubectl apply -f mysql-service.yaml

4) Aplicar backend:
   kubectl apply -f backend-deployment.yaml
   kubectl apply -f backend-service.yaml

5) Aplicar frontend:
   kubectl apply -f frontend-deployment.yaml
   kubectl apply -f frontend-service.yaml

6) Verificar:
   kubectl get pods -n tienda
   kubectl get svc tienda-frontend -n tienda

Copias el EXTERNAL-IP (DNS del ELB) â†’ lo abres en el navegadorâ†’ deberÃ­as ver la pÃ¡gina de Tienda de Perritos í ½í°¶

Nota: Si te da error, y sale el pod con estado Pending (valida correctamente la configuraciÃ³n de la Actividad 1 â€“ paso 4).

