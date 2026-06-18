# Tienda de Perritos — Infraestructura EKS en AWS Academy

> Repositorio del laboratorio **duoc/intro-devops**: despliegue de una aplicación web de tres capas (frontend, backend, base de datos) sobre Amazon EKS, provisonado con Terraform y desplegado con manifiestos de Kubernetes.

---

## Tabla de contenidos

- [1. Introducción al proyecto](#1-introducción-al-proyecto)
- [2. Arquitectura general](#2-arquitectura-general)
- [3. Componentes del repositorio](#3-componentes-del-repositorio)
  - [3.1. `terraform/` — Infraestructura con Terraform (cluster/ y addons/)](#31-terraform--infraestructura-con-terraform-cluster-y-addons)
  - [3.2. `app-k8s/` — Aplicación contenerizada y manifiestos Kubernetes](#32-app-k8s--aplicación-contenerizada-y-manifiestos-kubernetes)
- [4. Instrucciones de uso](#4-instrucciones-de-uso)
  - [4.1. Prerrequisitos](#41-prerrequisitos)
  - [4.2. Provisionar la infraestructura (Terraform)](#42-provisionar-la-infraestructura-terraform)
  - [4.3. Construir y publicar imágenes en ECR (Makefile)](#43-construir-y-publicar-imágenes-en-ecr-makefile)
  - [4.4. Desplegar la aplicación en EKS](#44-desplegar-la-aplicación-en-eks)
  - [4.5. Acceder a la aplicación desde Internet](#45-acceder-a-la-aplicación-desde-internet)
  - [4.6. Desmantelamiento (teardown)](#46-desmantelamiento-teardown)
- [5. Variables relevantes de AWS Academy](#5-variables-relevantes-de-aws-academy)
  - [5.1. Credenciales de sesión](#51-credenciales-de-sesión)
  - [5.2. Roles IAM preexistentes](#52-roles-iam-preexistentes)
  - [5.3. Variables de Terraform](#53-variables-de-terraform)
- [6. Validación de componentes](#6-validación-de-componentes)
  - [6.1. Descubrir los nombres de los roles IAM](#61-descubrir-los-nombres-de-los-roles-iam)
  - [6.2. Validación del clúster EKS](#62-validación-del-clúster-eks)
  - [6.3. Validación del AWS Load Balancer Controller](#63-validación-del-aws-load-balancer-controller)
  - [6.4. Validación de los pods y servicios de la aplicación](#64-validación-de-los-pods-y-servicios-de-la-aplicación)
  - [6.5. Validación del NLB y el target group](#65-validación-del-nlb-y-el-target-group)
  - [6.6. Validación de las imágenes ECR](#66-validación-de-las-imágenes-ecr)
  - [6.7. Validación de conectividad end-to-end](#67-validación-de-conectividad-end-to-end)
- [7. Detalles técnicos de cada componente](#7-detalles-técnicos-de-cada-componente)
  - [7.1. Módulo `network`](#71-módulo-network)
  - [7.2. Módulo `security_groups`](#72-módulo-security_groups)
  - [7.3. Módulo `eks`](#73-módulo-eks)
  - [7.4. Módulo `ecr`](#74-módulo-ecr)
  - [7.5. Recursos raíz adicionales](#75-recursos-raíz-adicionales)
  - [7.6. Aplicación: backend (Node.js / Express)](#76-aplicación-backend-nodejs--express)
  - [7.7. Aplicación: frontend (Nginx + JS)](#77-aplicación-frontend-nginx--js)
  - [7.8. Aplicación: base de datos (MySQL 8)](#78-aplicación-base-de-datos-mysql-8)
- [8. Modelo de autenticación del LBC](#8-modelo-de-autenticación-del-lbc)
- [9. Solución de problemas](#9-solución-de-problemas)
- [10. Notas y advertencias importantes](#10-notas-y-advertencias-importantes)
- [11. Estructura del repositorio](#11-estructura-del-repositorio)

---

## 1. Introducción al proyecto

Este repositorio contiene todo el código necesario para levantar una aplicación web de tres capas — denominada **«Tienda de Perritos»**— en un clúster de Amazon EKS (Elastic Kubernetes Service) dentro de un entorno de **AWS Academy** (Vocareum). El proyecto está diseñado como una actividad práctica para el curso de Introducción a DevOps, y abarca desde la provisión de infraestructura con Terraform hasta el despliegue de contenedores en Kubernetes.

La aplicación consta de tres servicios:

| Servicio | Tecnología | Descripción |
|----------|-----------|-------------|
| **Frontend** | Nginx + JavaScript vanilla | Interfaz web que presenta un catálogo de alimentos para perros y permite operaciones CRUD |
| **Backend** | Node.js 18 + Express + mysql2 | API REST que expone endpoints `/api/productos` y gestiona la conexión a la base de datos |
| **Base de datos** | MySQL 8 | Almacena la tabla `productos` con datos iniciales de productos de alimentos para perros |

La infraestructura se provisiona de forma declarativa con Terraform e incluye:

- **VPC** con subredes públicas y privadas (6 subredes en total), Internet Gateway y NAT Gateway
- **Clúster EKS** con node group de instancias SPOT `t3.large`
- **Repositorios ECR** para las tres imágenes de contenedor
- **Security groups** para el clúster y los nodos worker
- **AWS Load Balancer Controller** instalado vía Helm para provisionar NLBs públicos
- **CloudWatch Logs** para los logs del plano de control de EKS
- **EKS Add-ons**: VPC CNI, CloudWatch Observability y Metrics Server

El despliegue de la aplicación en Kubernetes se realiza con manifiestos YAML estáticos e incluye Horizontal Pod Autoscalers (HPA) para el backend y el frontend, probes de salud (_readiness_ y _liveness_), y un Service de tipo LoadBalancer para exponer el frontend a Internet.

---

## 2. Arquitectura general

```
                     ┌──────────────────────────────────┐
                     │     Internet / Navegador         │
                     └──────────────┬───────────────────┘
                                    │
                          ┌─────────▼─────────┐
                          │   NLB (público)   │   ← AWS Load Balancer Controller
                          │  puerto 80 → 80   │     provisiona un Network Load Balancer
                          └─────────┬─────────┘
                                    │
               ┌────────────────────┼─────────────────────┐
               │                    │                     │
        ┌──────▼──────┐     ┌───────▼──────┐     ┌────────▼─────┐
        │  Frontend   │     │  Frontend    │     │   Backend    │
        │  (pod)      │     │  (pod)       │     │   (pod)      │
        │  Nginx:80   │     │  Nginx:80    │     │   Express    │
        │  proxy /api │     │  proxy /api  │     │   :3001      │
        └──────┬──────┘     └───────┬──────┘     └────────┬─────┘
               │                    │                     │
               └────────────────────┼─────────────────────┘
                                    │
                          ┌─────────▼─────────┐
                          │   MySQL (pod)     │
                          │   tienda-db:3306  │
                          │   (headless svc)  │
                          └───────────────────┘
                                    │
                          ┌─────────▼─────────┐
                          │  emptyDir volume  │  ← datos efímeros (lab only)
                          └───────────────────┘

               ┌─────────────────────────────────────────────┐
               │            VPC 10.0.0.0/20                  │
               │                                             │
               │  ┌─────────────────┐ ┌──────────────────┐   │
               │  │ Public Subnet   │ │ Public Subnet    │   │
               │  │ us-east-1a      │ │ us-east-1b       │   │
               │  │ (NAT GW + IGW)  │ │ (NLB targets)    │   │
               │  └─────────────────┘ └──────────────────┘   │
               │  ┌─────────────────┐ ┌─────────────────┐    │
               │  │ Priv. App Subnet│ │ Priv. App Subnet│    │
               │  │ us-east-1a      │ │ us-east-1b      │    │
               │  └─────────────────┘ └─────────────────┘    │
               │  ┌─────────────────┐ ┌─────────────────┐    │
               │  │ Priv. Data Sub. │ │ Priv. Data Sub. │    │
               │  │ us-east-1a      │ │ us-east-1b      │    │
               │  └─────────────────┘ └─────────────────┘    │
               │                                             │
               │  EKS Cluster: tienda-eks (v1.30)            │
               │  Node Group: SPOT t3.large (1-3 nodos)      │
               │  ECR: tienda-frontend, tienda-backend,      │
               │        tienda-db                            │
               └─────────────────────────────────────────────┘
```

**Flujo de una petición HTTP:**

1. El navegador envía la petición al DNS del NLB (proporcionado por AWS como `EXTERNAL-IP` del Service `tienda-frontend`).
2. El NLB enruta el tráfico al puerto 80 de los pods del frontend (a través del target group).
3. Si la petición coincide con `/api/`, Nginx hace proxy reverso hacia `http://tienda-backend:3001`.
4. El backend consulta MySQL en `tienda-db:3306` y devuelve la respuesta.
5. Las peticiones de contenido estático (`/`, `index.html`, `app.js`) son servidas directamente por Nginx.

---

## 3. Componentes del repositorio

### 3.1. `terraform/` — Infraestructura con Terraform (cluster/ y addons/)

Este directorio contiene **toda la infraestructura como código** necesaria para provisionar el clúster EKS y sus dependencias, dividida en **dos módulos raíz** que se aplican en orden:

- **`terraform/cluster/`** — Aprovisiona el VPC, los security groups, el clúster EKS, el node group y los repositorios ECR. **No tiene providers de kubernetes/helm**, así que un `terraform plan` en greenfield no falla por la falta del clúster.
- **`terraform/addons/`** — Instala el Helm release del AWS Load Balancer Controller y su Secret `aws-credentials` en `kube-system`. Lee los outputs de `cluster/` (endpoint, CA, VPC ID) vía `terraform_remote_state`. **`cluster/` debe haberse aplicado al menos una vez antes de que `addons/` pueda hacer `plan`.**

#### Estructura interna

```
terraform/
├── cluster/                   # Root 1: AWS-only (VPC, SGs, EKS, ECR)
│   ├── versions.tf            # Solo provider `aws` (+ external)
│   ├── variables.tf           # region, vpc_*, cluster_*, node_*, ecr_repo_names, common_tags
│   ├── main.tf                # Orquestación de los 4 módulos + check de credenciales
│   ├── outputs.tf             # cluster_name, cluster_endpoint, cluster_ca_data, vpc_id, ecr_*
│   ├── terraform.tfvars.example
│   ├── .gitignore
│   └── (terraform.tfvars)     # Crear a partir del .example con los roles descubiertos
├── addons/                    # Root 2: kubernetes/helm (LBC, Secret)
│   ├── versions.tf            # providers aws + kubernetes + helm + external
│   ├── variables.tf           # region, cluster_name, common_tags + aws_*_credential
│   ├── main.tf                # data.terraform_remote_state.cluster + kubernetes_secret + helm_release
│   ├── outputs.tf             # kubeconfig_command, lbc_release_name
│   ├── terraform.tfvars.example
│   ├── .gitignore
│   └── (terraform.tfvars)     # Crear a partir del .example
├── modules/                   # Módulos compartidos por ambos roots
│   ├── network/               # VPC, subnets, IGW, NAT GW, route tables
│   ├── security_groups/       # SG del clúster y de los nodos worker
│   ├── eks/                   # Clúster EKS, node group, add-ons, log group
│   └── ecr/                   # Repositorios ECR para las imágenes Docker
├── export_vars.sh             # Script para exportar credenciales AWS Academy
├── docs/                      # README, RUNBOOK, TROUBLESHOOTING (en/es)
└── README.md                  # README del subdirectorio terraform
```

#### Módulos de Terraform

| Módulo | Recursos que crea | Archivos |
|--------|-------------------|----------|
| `network` | VPC, 6 subnets (2 públicas, 2 privadas-app, 2 privadas-data), Internet Gateway, NAT Gateway con EIP, tablas de ruteo públicas y privadas | `main.tf`, `variables.tf`, `outputs.tf` |
| `security_groups` | SG del clúster EKS (`eks-cluster-sg`) y SG de los nodos worker (`eks-nodes-sg`) con reglas de ingreso cruzadas | `main.tf`, `variables.tf`, `outputs.tf` |
| `eks` | Log group de CloudWatch, clúster EKS, node group (SPOT t3.large, 1-3 nodos), 3 add-ons (vpc-cni, cloudwatch-observability, metrics-server) | `main.tf`, `variables.tf`, `outputs.tf` |
| `ecr` | 3 repositorios ECR mutables con scan-on-push habilitado | `main.tf`, `variables.tf`, `outputs.tf` |

#### ¿Por qué dos roots?

El root `addons/` necesita los providers `kubernetes` y `helm` configurados con el endpoint y el CA del clúster. Si ambos roots vivieran en un único módulo, esos providers forzarían una lectura de `data.aws_eks_cluster` durante el plan, antes de que el clúster exista — y eso falla en un apply greenfield con `Error: reading EKS Cluster (tienda-eks): couldn't find resource`. Dividir en dos roots hace que cada uno planifique de forma independiente.

#### Recursos creados en cada root

**`terraform/cluster/main.tf`** crea:

- **`data "aws_caller_identity" "current"`** — Obtiene el ID de cuenta para el comando de login a ECR.
- **`data "external" "aws_env"`** — Lee las credenciales AWS del entorno shell cuando las variables de Terraform son `null`.
- **`check "aws_credentials_present"`** — Validación pre-plan que falla si las credenciales AWS no están configuradas.

**`terraform/addons/main.tf`** crea:

- **`data "terraform_remote_state" "cluster"`** — Lee los outputs de `cluster/` (`cluster_endpoint`, `cluster_ca_data`, `vpc_id`) para configurar los providers de kubernetes/helm.
- **`kubernetes_secret "aws_credentials"`** — Secret `aws-credentials` en `kube-system` con las credenciales STS del estudiante.
- **`helm_release "aws_load_balancer_controller"`** — Instalación del AWS LBC vía Helm con autenticación vía Secret (sin IRSA).

### 3.2. `app-k8s/` — Aplicación contenerizada y manifiestos Kubernetes

Este directorio contiene el código fuente de la aplicación, los Dockerfiles y los manifiestos de Kubernetes.

```
app-k8s/
├── Makefile                  # Automatización de build/tag/push a ECR
├── backend/
│   ├── Dockerfile            # Imagen Node.js 18-alpine
│   ├── server.js             # API REST Express
│   └── package.json          # Dependencias (express, cors, mysql2)
├── frontend/
│   ├── Dockerfile            # Imagen Nginx Alpine
│   ├── app.js                # Lógica CRUD del navegador
│   ├── index.html             # Página HTML de la tienda
│   └── default.conf          # Configuración de Nginx (proxy reverso)
├── db/
│   ├── Dockerfile            # Imagen MySQL 8 con DB inicializada
│   └── init.sql              # Script SQL con esquema y datos semilla
└── k8s/
    ├── namespace.yaml         # Namespace "tienda"
    ├── mysql-secret.yaml      # Secret con contraseña root de MySQL
    ├── mysql-deployment.yaml  # Deployment de MySQL (1 réplica)
    ├── mysql-service.yaml     # Service headless para MySQL
    ├── backend-deployment.yaml # Deployment del backend (2 réplicas, HPA)
    ├── backend-service.yaml    # Service ClusterIP para el backend
    ├── backend-hpa.yaml       # HPA: 2-10 réplicas al 70% CPU
    ├── frontend-deployment.yaml # Deployment del frontend (2 réplicas, HPA)
    ├── frontend-service.yaml   # Service LoadBalancer (NLB público)
    ├── frontend-hpa.yaml       # HPA: 2-6 réplicas al 60% CPU
    └── README.txt              # Instrucciones paso a paso de despliegue
```

---

## 4. Instrucciones de uso

### 4.1. Prerrequisitos

Antes de comenzar, asegúrate de tener instaladas las siguientes herramientas:

| Herramienta | Versión mínima | Propósito |
|-------------|---------------|-----------|
| **Terraform** | ≥ 1.5 | Provisionamiento de infraestructura |
| **AWS CLI v2** | Cualquiera reciente | Interacción con APIs de AWS, login a ECR |
| **kubectl** | Compatible con EKS 1.30+ | Gestión del clúster Kubernetes |
| **Docker** | Cualquiera reciente | Construcción de imágenes de contenedor |
| **jq** | Cualquiera reciente | Procesamiento de JSON (usado por los data sources `external` en `cluster/` y `addons/`) |
| **Helm** | 3.x | Gestión del chart del LBC (instalado por Terraform) |

Además, necesitas:

- Una **sesión de laboratorio de AWS Academy activa** (estado verde en Vocareum)
- Haber hecho clic en **Start Lab** en Vocareum y copiado las credenciales del panel **AWS Details**

### 4.2. Provisionar la infraestructura (Terraform)

Los dos roots se aplican en orden: **`terraform/cluster/` primero**, luego **`terraform/addons/`**. Cada `cd` importa — `terraform_remote_state` en `addons/` lee `../cluster/terraform.tfstate` y sólo resuelve cuando ejecutas desde dentro de `terraform/addons/`.

#### Paso 1: Configurar credenciales de AWS Academy

En Vocareum, haz clic en **AWS Details** → **AWS CLI** → **Show** y copia los tres valores de llaves secretasl. Luego ejecuta:

```bash
# Editar el script de exportación con los valores de tu sesión actual
$EDITOR terraform/export_vars.sh
# O pegar los valores directamente a mano

# Cargar las credenciales en el shell (mismo shell que ejecutará terraform)
source terraform/export_vars.sh
# O exportarlas manualmente:
export AWS_ACCESS_KEY_ID="ASIAR..."
export AWS_SECRET_ACCESS_KEY="U64p..."
export AWS_SESSION_TOKEN="IQoJb3JpZ2lu..."
```

> ⚠️ **Importante:** Las credenciales de AWS Academy expiran cada ~3 horas. Cuando expiren, necesitarás re-exportarlas y volver a ejecutar `terraform apply` en `terraform/addons/` para refrescar el Secret de Kubernetes.

#### Paso 2: Descubrir los nombres de los roles IAM

Consulta la sección [6.1](#61-descubrir-los-nombres-de-los-roles-iam) más abajo para los one-liners que descubren los roles `LabEksClusterRole-*` y `LabEksNodeRole-*` en tu cuenta. **Nunca** copies estos valores de otro estudiante.

#### Paso 3: Configurar las variables de Terraform

```bash
# Para cluster/ (necesita los nombres de los roles)
cp terraform/cluster/terraform.tfvars.example terraform/cluster/terraform.tfvars
$EDITOR terraform/cluster/terraform.tfvars

# Para addons/ (no necesita roles IAM — solo region/cluster_name)
cp terraform/addons/terraform.tfvars.example terraform/addons/terraform.tfvars
```

Edita `terraform/cluster/terraform.tfvars` con los valores descubiertos en el paso 2:

```hcl
region              = "us-east-1"
cluster_name        = "tienda-eks"
cluster_version     = "1.30"
cluster_role_name   = "cXXXXXXXXXXXXX-LabEksClusterRole-XXXXXXXXXXXX"   # de §6.1
node_role_name      = "cXXXXXXXXXXXXX-LabEksNodeRole-XXXXXXXXXXXX"      # de §6.1
```

> **Nota sobre `cluster_role_name` y `node_role_name`**: Estos valores son **específicos de cada cuenta** de AWS Academy. **Nunca** copies los valores del ejemplo o de otro estudiante — usa siempre los que aparezcan en tu consola de AWS o los descubiertos en §6.1.

#### Paso 4: Aplicar `terraform/cluster/`

```bash
cd terraform/cluster
terraform init
terraform plan      # Revisar qué se va a crear
terraform apply     # Aprovisiona VPC + SGs + EKS + ECR (~10-15 min)
```

Durante el `apply` de `cluster/` se crea, en orden:

1. VPC, subnets, gateways y tablas de ruteo (módulo `network`)
2. Tags de Kubernetes en las subnets (ELB role tags)
3. Security groups del clúster y nodos
4. Repositorios ECR
5. Clúster EKS (~10-15 minutos)
6. Node group (~5-10 minutos adicionales)
7. EKS Add-ons (vpc-cni, cloudwatch-observability, metrics-server)

#### Paso 5: Aplicar `terraform/addons/`

```bash
cd ../addons
terraform init
terraform plan      # Lee los outputs de cluster/ vía terraform_remote_state
terraform apply     # Crea el Secret + Helm release del LBC (~2 min)
```

Durante el `apply` de `addons/` se crea:

8. Secret de Kubernetes con credenciales AWS (en `kube-system`)
9. Helm release del AWS Load Balancer Controller

#### Paso 6: Conectar kubectl al clúster

```bash
aws eks update-kubeconfig --region us-east-1 --name <nombre de tu cluster de EKS>

# Verificar la conexión:
kubectl get nodes
# Deberías ver al menos un nodo en estado Ready
```

### 4.3. Construir y publicar imágenes en ECR (Makefile)

El `Makefile` en `app-k8s/` automatiza el proceso de construir, etiquetar y publicar las imágenes Docker en ECR.

#### Variables del Makefile

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `account` | ID de cuenta AWS (requerido para login/push) | Sin valor (obligatorio) |
| `tag` | Etiqueta de la imagen Docker | `eks-v1` |
| `region` | Región AWS para ECR | `us-east-1` |
| `source` | Directorio base con los Dockerfiles | `.` (directorio actual) |

#### Targets del Makefile

| Target | Descripción |
|--------|-------------|
| `help` | Muestra la ayuda con las instrucciones de uso (target por defecto) |
| `check-docker` | Verifica que `docker` y `aws` estén instalados |
| `check-account` | Valida que `account` esté definido y sea un ID de 12 dígitos |
| `login` | Autentica Docker contra el registro ECR |
| `build` / `build-all` | Construye las tres imágenes localmente (`tienda-frontend`, `tienda-backend`, `tienda-db`) |
| `build-<servicio>` | Construye solo una imagen (`build-frontend`, `build-backend`, `build-db`) |
| `tag` / `tag-all` | Etiqueta las imágenes con el URI de ECR |
| `tag-<servicio>` | Etiqueta solo una imagen |
| `push` / `push-all` | Sube las imágenes etiquetadas a ECR |
| `push-<servicio>` | Sube solo una imagen |
| `publish` / `publish-all` | Atajo: login + build + tag + push de los tres servicios |
| `publish-<servicio>` | Atajo para un solo servicio |
| `clean` | Elimina las imágenes locales (no afecta ECR) |

#### Ejemplos de uso

```bash
cd app-k8s

# Ver la ayuda
make help

# Paso 1: Login en ECR (requiere el ID de cuenta)
make account=112769872808 login

# Paso 2: Construir, etiquetar y publicar los tres servicios
make account=112769872808 publish-all tag=eks-v1

# O hacerlo servicio por servicio:
make account=112769872808 publish-frontend tag=eks-v1
make account=112769872808 publish-backend tag=eks-v1
make account=112769872808 publish-db tag=eks-v1

# Construir sin publicar (no requiere account):
make build-all

# Limpiar imágenes locales:
make clean

# Limpiar incluyendo las etiquetadas para ECR:
make account=112769872808 clean
```

> **Nota:** El ID de cuenta (`112769872808` en los ejemplos) es el de tu sesión de AWS Academy. Se muestra en la salida de `aws sts get-caller-identity`.

### 4.4. Desplegar la aplicación en EKS

Una vez que las imágenes estén en ECR y el clúster esté funcionando:

```bash
# Aplicar todos los manifiestos en orden:
kubectl apply -f app-k8s/k8s/namespace.yaml
kubectl apply -f app-k8s/k8s/mysql-secret.yaml
kubectl apply -f app-k8s/k8s/mysql-deployment.yaml
kubectl apply -f app-k8s/k8s/mysql-service.yaml
kubectl apply -f app-k8s/k8s/backend-deployment.yaml
kubectl apply -f app-k8s/k8s/backend-service.yaml
kubectl apply -f app-k8s/k8s/backend-hpa.yaml
kubectl apply -f app-k8s/k8s/frontend-deployment.yaml
kubectl apply -f app-k8s/k8s/frontend-service.yaml
kubectl apply -f app-k8s/k8s/frontend-hpa.yaml
```

O aplicar todo de una vez (el namespace primero):

```bash
kubectl apply -f app-k8s/k8s/namespace.yaml
kubectl apply -f app-k8s/k8s/
```

### 4.5. Acceder a la aplicación desde Internet

```bash
# Verificar que los pods están corriendo:
kubectl get pods -n tienda

# Obtener la URL del LoadBalancer:
kubectl get svc tienda-frontend -n tienda

# El campo EXTERNAL-IP mostrará el DNS del NLB, por ejemplo:
# k8s-tienda-tienda-f3abc45d6e-1234567890.us-east-1.elb.amazonaws.com
```

Abre esa URL en un navegador. Deberías ver la página de **«Tienda de Alimentos para Perritos»** con la lista de productos.

### 4.6. Desmantelamiento (teardown)

```bash
# 1. Eliminar los recursos de Kubernetes:
kubectl delete -f app-k8s/k8s/

# 2. Destruir addons/ primero (para que el LBC limpie el NLB vía sus finalizers):
cd terraform/addons
terraform destroy

# 3. Destruir cluster/:
cd ../cluster
terraform destroy
```

`terraform destroy` hace lo siguiente en orden:

1. **`addons/`**: desinstala el Helm release del LBC (los finalizers eliminan el NLB y su security group).
2. **`cluster/`**: elimina los repositorios ECR (y cualquier imagen que contengan), el clúster EKS y el node group (~10 minutos), y desmonta el VPC, subnets, gateways y tablas de ruteo.

> **Si `terraform destroy` falla** porque el NLB no se elimina, consulta la sección [9. Solución de problemas](#9-solución-de-problemas).

#### 4.6.1. Limpieza manual desde la consola de AWS (cuando `terraform destroy` no alcanza)

En AWS Academy, `terraform destroy` no siempre logra dejar la cuenta limpia. Los motivos típicos son:

- El **AWS Load Balancer Controller (LBC)** crea los load balancers directamente en AWS, fuera del estado de Terraform. Mientras el chart siga instalado, el LBC sigue observando los `Service` de Kubernetes y **recrea** cualquier load balancer que Terraform (o un humano) intente borrar. Esto se manifiesta como un NLB huérfano que vuelve a aparecer segundos después de eliminarlo.
- Las **subnets públicas** quedan enganchadas a los ENIs de los load balancers y a los ENIs del node group. AWS rechaza el borrado de la subnet con `DependencyViolation` mientras haya ENIs activos.
- El **node group vive en las subnets públicas** (`node_subnet_ids = module.network.public_subnet_ids` en `main.tf`), por lo que sus ENIs también bloquean el borrado de esas subnets.
- El **NAT Gateway** mantiene un ENI en `public-subnet-1` que en ocasiones no se libera a tiempo.

Si después de correr `terraform destroy` quedan recursos en la consola, el orden de limpieza manual es el siguiente. **Es importante respetar el orden: load balancer → subnets → VPC.** Si se intenta borrar la VPC o las subnets primero, AWS lo va a rechazar.

**Paso 1 — Borrar los `Service` de tipo `LoadBalancer` desde la consola de EKS**

1. En la consola de AWS, ve a **Amazon EKS → Clusters → `tienda-eks-1` → Resources → Service**.
2. Identifica los servicios de tipo `LoadBalancer` (frontend, backend, db). Verás un ícono de balanceador junto a cada uno.
3. Selecciónalos, presiona **Delete** y confirma con **Delete** en el diálogo.
4. Kubernetes los marca para borrar; el AWS Load Balancer Controller, que está observando, llama internamente a `DeleteLoadBalancer` y los ENIs asociados se liberan.

   > **Importante:** este paso puede demorar 1–2 minutos. Antes de continuar al paso siguiente, confirma que el load balancer ya no existe.

5. Verifica yendo a **EC2 → Load balancers**. El NLB que apuntaba a la aplicación (`k8s-tienda-tienda-…`) ya no debe estar en la lista. Si todavía aparece, espera 30 segundos y refresca; el LBC hace la reconciliación cada ~10 segundos.

**Paso 2 — Borrar el load balancer (si quedó huérfano)**

Si después del paso 1 el load balancer sigue ahí, bórralo manualmente:

1. Ve a **EC2 → Load balancers**.
2. Selecciona el balanceador huérfano (su nombre suele empezar con `k8s-tienda-…`).
3. Presiona **Actions → Delete load balancer** y confirma.

   > Si la opción está gris, el balanceador está en estado `provisioning` o `active-unhealthy`. Espera unos segundos a que pase a `active` y vuelve a intentar.

4. Una vez eliminado el balanceador, ve a **EC2 → Network interfaces**, filtra por la VPC del laboratorio (`academy-vpc`) y borra cualquier ENI que quede con la descripción `ELB app/…`. AWS a veces no libera los ENIs en el momento; limpiarlos a mano desbloquea el siguiente paso.

**Paso 3 — Borrar las subnets**

1. Ve a **VPC → Subnets**.
2. Filtra por la VPC del laboratorio (`academy-vpc`). Verás 6 subnets: 2 públicas, 2 privadas para app, 2 privadas para datos.
3. Empieza por las subnets **privadas para datos** (`private-data-subnet-1`, `private-data-subnet-2`). Selecciónalas, presiona **Actions → Delete subnet** y confirma.
4. Repite con las subnets **privadas para app** (`private-app-subnet-1`, `private-app-subnet-2`).
5. Ahora las **públicas** (`public-subnet-1`, `public-subnet-2`). En este punto, el NAT Gateway de la subnet pública 1 ya fue borrado por Terraform, pero su ENI puede haber quedado. Si la consola rechaza el borrado con `DependencyViolation`:
   - Ve a **EC2 → Network interfaces**, busca los ENIs en `public-subnet-1` que no sean de instancias EC2, y bórralos manualmente (el más común es el del NAT Gateway).
   - Vuelve a **VPC → Subnets** y reintenta la eliminación.
6. Confirma que las 6 subnets hayan desaparecido del listado de la VPC.

**Paso 4 — Borrar el Internet Gateway y las tablas de ruteo**

1. Ve a **VPC → Internet gateways**. Selecciona el `academy-igw` (que ya debe estar detached) y presiona **Actions → Delete internet gateway**.
2. Ve a **VPC → Route tables**. La consola no permite borrar una tabla de ruteo mientras tenga asociaciones; primero hay que eliminar las asociaciones y luego la tabla. Las tablas creadas por Terraform (con tag `Name = public-rt` o `private-rt`) ya deberían estar sin asociaciones en este punto; bórralas.

**Paso 5 — Borrar la VPC**

1. Ve a **VPC → Your VPCs**.
2. Selecciona `academy-vpc`, presiona **Actions → Delete VPC** y confirma.
3. AWS revisa que no haya recursos asociados. Si el borrado falla, vuelve a los pasos anteriores y revisa que no quede ninguna subnet, ENI, IGW ni tabla de ruteo colgados.

**Paso 6 — Verificación final**

1. En **VPC → Your VPCs**, `academy-vpc` ya no debe aparecer.
2. En **EC2 → Load balancers**, no debe haber ningún balanceador `k8s-…`.
3. En **EC2 → Network interfaces**, filtra por la VPC eliminada: la lista debe estar vacía.
4. En **EKS → Clusters**, `tienda-eks-1` debe estar en estado `DELETING` o ya no aparecer.

> **Si la VPC no se borra porque hay ENIs de un balanceador huérfano que no detectaste en el paso 2:** revisa el tag de esos ENIs (suelen tener `elbv2.k8s.aws/cluster: tienda-eks-1` en su descripción). Esos ENIs son la huella del load balancer y AWS los considera "recursos activos" hasta que los borres explícitamente.

> **Si esto se repite en futuros teardowns:** revisa la sección 9 (Solución de problemas) o, en `terraform/cluster/main.tf`, agregá un `null_resource` con `provisioner "local-exec"` que en el bloque `destroy` borre los `Service` de tipo `LoadBalancer` antes de que Terraform intente eliminar las subnets. Eso automatiza el paso 1 de esta guía y deja el teardown funcionando con un solo comando.

---

## 5. Variables relevantes de AWS Academy

### 5.1. Credenciales de sesión

AWS Academy utiliza roles STS temporales (`voclabs`) que expiran cada ~3 horas. Necesitas tres valores del panel **AWS Details** en Vocareum:

| Variable de entorno | Dónde obtenerla | Descripción |
|---------------------|-----------------|-------------|
| `AWS_ACCESS_KEY_ID` | Panel AWS Details → Show | Clave de acceso STS (comienza con `ASIA...`) |
| `AWS_SECRET_ACCESS_KEY` | Panel AWS Details → Show | Clave secreta STS |
| `AWS_SESSION_TOKEN` | Panel AWS Details → Show | Token de sesión STS (largo, comienza con `IQoJ...`) |

Puedes exportarlas manualmente o editar y ejecutar `export_vars.sh`:

```bash
# Editar con los valores actuales de tu sesión:
$EDITOR terraform/export_vars.sh

# Exportar:
source terraform/export_vars.sh
```

> ⚠️ **Estas credenciales son temporales y se renuevan al reiniciar el lab. Nunca las compartas ni las commitées en un repositorio público.**

### 5.2. Roles IAM preexistentes

AWS Academy pre-crea dos roles IAM en cada cuenta de laboratorio. Sus nombres son **específicos de cada cuenta** (contienen un hash único):

| Rol | Patrón del nombre | Propósito |
|-----|-------------------|-----------|
| Cluster role | `c<hash>-LabEksClusterRole-<random>` | Rol de IAM para el plano de control de EKS. Confía en `eks.amazonaws.com`. Tiene las policies AWS-managed para el control plane (`AmazonEKSClusterPolicy`, etc.) |
| Node role | `c<hash>-LabEksNodeRole-<random>` | Rol de IAM para los nodos worker. Confía en `ec2.amazonaws.com`. Tiene las policies AWS-managed para nodos (`AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKSWorkerNodePolicy`) |

**No copies estos nombres de otro estudiante.** Descúbrelos en tu cuenta con los one-liners de la sección [6.1](#61-descubrir-los-nombres-de-los-roles-iam) más abajo, o visualmente con las instrucciones de la consola que siguen.

#### 5.2.1. Cómo obtener los nombres de los roles desde la consola de AWS

Si preferís verificar visualmente los roles, podés buscarlos directamente en la consola. Hay dos caminos equivalentes: la **consola de EKS** (guiada, parte desde el servicio que los usa) y la **consola de IAM** (genérica, sirve para cualquier rol de la cuenta).

**Camino A — Desde la consola de EKS (recomendado para el cluster role)**

1. Abrí la consola de AWS y andá a **Amazon EKS → Clusters**.
2. Hacé clic en el nombre de tu clúster (por ejemplo, `tienda-eks-1`).
3. En la pestaña **Overview**, expandí la sección **Details**.
4. Buscá el campo **Cluster IAM role ARN** (o **Kubernetes API server role**). El ARN tiene la forma:

   ```
   arn:aws:iam::<account-id>:role/c<hash>-LabEksClusterRole-<random>
   ```

5. La parte final del ARN, después de `role/`, **es exactamente el valor que tenés que poner en `cluster_role_name`** dentro de `terraform.tfvars`. Copialo tal cual, sin el prefijo `arn:aws:iam::...:role/`.

> **Por qué este camino funciona:** EKS muestra el rol porque ya está asociado al plano de control del clúster. La consola es la fuente de verdad: si ves el ARN acá, ese rol existe en IAM y tiene las policies necesarias.

**Camino B — Desde la consola de IAM (genérico, sirve para los dos roles)**

1. Andá a **IAM → Roles** (en el panel lateral izquierdo, dentro de **Access management**).
2. En la barra de búsqueda, escribí `LabEksClusterRole`. IAM filtra por nombre y por ARN; el nombre completo (con el `c<hash>-` adelante) tiene que aparecer en la columna **Role name**.
3. Anotá el nombre exacto que aparece en la columna **Role name**. No copies el ARN, solo el nombre.
4. Repetí la búsqueda con `LabEksNodeRole` para el rol de los nodos worker.
5. Si la búsqueda no devuelve resultados, probá filtrando por la fecha de creación (**Created**). En AWS Academy, los roles del lab se crean al inicio de la sesión y aparecen con la fecha más reciente.

**Cómo distinguir el cluster role del node role**

Si por alguna razón ambos aparecen con nombres similares en la lista, abrí cada rol y revisá dos cosas en la pestaña **Trust relationships**:

| Pista | Cluster role | Node role |
|-------|--------------|-----------|
| Entidad que confía (Service) | `eks.amazonaws.com` | `ec2.amazonaws.com` |
| Policies adjuntas (pestaña **Permissions**) | `AmazonEKSClusterPolicy` (+ variantes) | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |

El cluster role es el que confía en EKS; el node role es el que confía en EC2. Las policies también son diferentes: el cluster role tiene políticas de control plane, el node role tiene políticas de CNI, registro y worker.

**Una vez que tengas los dos nombres, pegalos en `terraform.tfvars`:**

```hcl
# terraform/cluster/terraform.tfvars
cluster_role_name = "c<hash>-LabEksClusterRole-<random>"   # ← nombre de la consola
node_role_name    = "c<hash>-LabEksNodeRole-<random>"      # ← nombre de la consola
```

> ⚠️ **Pegá solo el nombre, no el ARN.** Terraform espera el nombre corto (`RoleName`); si le pasás el ARN completo, el data source `aws_iam_role` falla con `NoSuchEntity`.

> ℹ️ **Los nombres cambian entre cuentas de laboratorio.** Cada cuenta de AWS Academy tiene su propio `c<hash>` y sufijo aleatorio. Nunca copies estos valores desde otro estudiante ni desde un tutorial.

### 5.3. Variables de Terraform

Tras la división en dos roots, las variables se reparten así:

- **Variables de `cluster/`** — se configuran en `terraform/cluster/terraform.tfvars`. Necesitan los nombres de los roles IAM.
- **Variables de `addons/`** — se configuran en `terraform/addons/terraform.tfvars`. Sólo `region` y `cluster_name` necesitan coincidir con `cluster/`.

| Variable | Tipo | Default | Root | Descripción |
|----------|------|---------|------|-------------|
| `region` | `string` | `us-east-1` | ambos | Región AWS donde se despliegan todos los recursos. Debe coincidir entre los dos roots. |
| `vpc_cidr` | `string` | `10.0.0.0/20` | `cluster/` | Bloque CIDR de la VPC (4096 direcciones) |
| `azs` | `list(string)` | `["us-east-1a", "us-east-1b"]` | `cluster/` | Zonas de disponibilidad para las subnets |
| `public_subnet_newbits` | `number` | `4` | `cluster/` | Bits adicionales para subdividir la VPC en subnets públicas |
| `public_subnet_offset` | `number` | `0` | `cluster/` | Offset para el cálculo de CIDR de subnets públicas |
| `private_app_subnet_offset` | `number` | `2` | `cluster/` | Offset para subnets de aplicación privadas |
| `private_data_subnet_offset` | `number` | `4` | `cluster/` | Offset para subnets de datos privadas |
| `map_public_ip_on_launch` | `bool` | `true` | `cluster/` | Asignar IPs públicas automáticamente en subnets públicas |
| `enable_dns_support` | `bool` | `true` | `cluster/` | Habilitar soporte DNS en la VPC |
| `enable_dns_hostnames` | `bool` | `true` | `cluster/` | Habilitar hostnames DNS en la VPC |
| `cluster_name` | `string` | `tienda-eks` | ambos | Nombre del clúster EKS. Debe coincidir entre los dos roots. |
| `cluster_version` | `string` | `1.30` | `cluster/` | Versión de Kubernetes para el clúster |
| `cluster_role_name` | `string` | — | `cluster/` | **Nombre exacto** del rol IAM para el clúster (descubierto con los one-liners de §6.1) |
| `node_role_name` | `string` | — | `cluster/` | **Nombre exacto** del rol IAM para los nodos (descubierto con los one-liners de §6.1) |
| `node_instance_type` | `string` | `t3.large` | `cluster/` | Tipo de instancia EC2 para los nodos worker |
| `node_desired_size` | `number` | `1` | `cluster/` | Número deseado de nodos |
| `node_min_size` | `number` | `1` | `cluster/` | Número mínimo de nodos |
| `node_max_size` | `number` | `3` | `cluster/` | Número máximo de nodos |
| `ecr_repo_names` | `list(string)` | `["tienda-frontend", "tienda-backend", "tienda-db"]` | `cluster/` | Nombres de los repositorios ECR |
| `aws_access_key_id` | `string` (sensitive) | `null` | `addons/` | Access key ID del LBC (si es `null`, se lee del entorno) |
| `aws_secret_access_key` | `string` (sensitive) | `null` | `addons/` | Secret access key del LBC (si es `null`, se lee del entorno) |
| `aws_session_token` | `string` (sensitive) | `null` | `addons/` | Session token del LBC (si es `null`, se lee del entorno) |
| `common_tags` | `map(string)` | `{}` | Tags aplicados a todos los recursos |

**Notas importantes sobre las credenciales en Terraform:**

- Si las variables `aws_access_key_id`, `aws_secret_access_key` y `aws_session_token` se dejan en `null` (valor por defecto) en `terraform/addons/terraform.tfvars`, Terraform las lee automáticamente de las variables de entorno (`AWS_ACCESS_KEY_ID`, AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) usando el data source `external` en `addons/main.tf`.
- El bloque `check "aws_credentials_present"` en `addons/main.tf` (y su gemelo en `cluster/main.tf`) valida que las tres credenciales estén presentes antes de ejecutar cualquier plan o apply. Si falta alguna, Terraform falla con un mensaje de error indicando que se debe ejecutar `source terraform/export_vars.sh`.

---

## 6. Validación de componentes

### 6.1. Descubrir los nombres de los roles IAM

AWS Academy pre-crea dos roles IAM en cada cuenta (`LabEksClusterRole-*` y `LabEksNodeRole-*`). Sus nombres son **específicos de cada cuenta** — nunca los copies de otro estudiante. Descúbrelos con estos one-liners (necesitas `jq` o `--output text`):

```bash
# Asegurate de tener las credenciales cargadas en este shell:
source terraform/export_vars.sh
aws sts get-caller-identity   # debe devolver assumed-role/voclabs/...

# Cluster role:
aws iam list-roles \
  --query 'Roles[?starts_with(RoleName, `LabEksClusterRole-`)].RoleName' \
  --output text
# Salida esperada: un único nombre como
#   c209142a5311394l14806637t1w112769872-LabEksClusterRole-XXXXXXXXXXXX

# Node role:
aws iam list-roles \
  --query 'Roles[?starts_with(RoleName, `LabEksNodeRole-`)].RoleName' \
  --output text
# Salida esperada: un único nombre como
#   c209142a5311394l14806637t1w112769872-LabEksNodeRole-XXXXXXXXXXXX
```

Si alguno de los dos comandos no devuelve nada, la sesión del laboratorio aún no provisionó los roles — iniciá el lab en Vocareum y esperá a que el indicador se ponga en verde.

**Una vez que tengas los dos nombres, pegalos en `terraform/cluster/terraform.tfvars`:**

```hcl
# terraform/cluster/terraform.tfvars
cluster_role_name = "c<hash>-LabEksClusterRole-<random>"   # ← nombre de la salida
node_role_name    = "c<hash>-LabEksNodeRole-<random>"      # ← nombre de la salida
```

> ⚠️ **Pegá solo el nombre, no el ARN.** Terraform espera el nombre corto (`RoleName`); si le pasás el ARN completo, el data source `aws_iam_role` falla con `NoSuchEntity`.

> ℹ️ **Los nombres cambian entre cuentas de laboratorio.** Cada cuenta de AWS Academy tiene su propio `c<hash>` y sufijo aleatorio. Nunca copies estos valores desde otro estudiante ni desde un tutorial.

### 6.2. Validación del clúster EKS

```bash
# Verificar estado del clúster
aws eks describe-cluster --name tienda-eks --region us-east-1 --query 'cluster.status'
# Esperado: "ACTIVE"

# Verificar los nodos
kubectl get nodes -o wide
# Esperado: al menos un nodo en estado Ready

# Verificar los add-ons
aws eks list-addons --cluster-name tienda-eks --region us-east-1
# Esperado: vpc-cni, amazon-cloudwatch-observability, metrics-server

# Verificar el kubeconfig
kubectl cluster-info
# Esperado: información del clúster EKS
```

### 6.3. Validación del AWS Load Balancer Controller

```bash
# Verificar que el pod del LBC está corriendo
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
# Esperado: 1/1 Running, READY = true

# Verificar logs del LBC (últimas 20 líneas)
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=20
# Buscar: reconciliaciones exitosas, sin errores ExpiredToken ni AccessDenied

# Verificar el Helm release
helm list -n kube-system
# Esperado: aws-load-balancer-controller con status deployed
```

### 6.4. Validación de los pods y servicios de la aplicación

```bash
# Verificar todos los pods en el namespace tienda
kubectl get pods -n tienda
# Esperado:
#   tienda-db-xxxx        1/1     Running
#   tienda-backend-xxxx   1/1     Running  (2 réplicas)
#   tienda-frontend-xxxx  1/1     Running  (2 réplicas)

# Verificar los servicios
kubectl get svc -n tienda
# Esperado:
#   tienda-db       ClusterIP   None       3306/TCP
#   tienda-backend  ClusterIP   10.x.x.x  3001/TCP
#   tienda-frontend LoadBalancer 10.x.x.x  80:3xxxx/TCP  k8s-tienda-...us-east-1.elb.amazonaws.com

# Verificar los HPA
kubectl get hpa -n tienda
# Esperado:
#   tienda-backend   Deployment/tienda-backend   70%/70%
#   tienda-frontend  Deployment/tienda-frontend   60%/60%

# Verificar los secrets
kubectl get secret mysql-secret -n tienda -o jsonpath='{.data}' | jq .
# Esperado: MYSQL_ROOT_PASSWORD decodificado como "admin123"

# Verificar los events (para diagnósticos)
kubectl get events -n tienda --sort-by='.lastTimestamp'
```

### 6.5. Validación del NLB y el target group

```bash
# Verificar que el NLB existe
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,Scheme:Scheme,Type:Type}'
# Esperado: un NLB con Scheme=internet-facing, Type=network

# Verificar la salud del target group
TG=$(aws elbv2 describe-target-groups --region us-east-1 \
  --query 'TargetGroups[?contains(LoadBalancerArns[0], `k8s`)].TargetGroupArn' --output text)

aws elbv2 describe-target-health --target-group-arn "$TG" --region us-east-1
# Esperado: todos los targets con State = healthy
```

### 6.6. Validación de las imágenes ECR

```bash
# Listar repositorios ECR
aws ecr describe-repositories --region us-east-1 --query 'repositories[].{Name:repositoryName,URI:repositoryUri}'
# Esperado: tienda-frontend, tienda-backend, tienda-db

# Verificar que las imágenes están disponibles
for repo in tienda-frontend tienda-backend tienda-db; do
  aws ecr describe-images --repository-name "$repo" --region us-east-1 \
    --query 'imageDetails[].{Tag:imageTags[0],Size:imageSizeInBytes,Pushed:pushedAt}'
done
# Cada uno debería tener la etiqueta "eks-v1"
```

### 6.7. Validación de conectividad end-to-end

```bash
# Obtener la URL del NLB
DNS=$(aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].DNSName' --output text)

# Probar el frontend
curl -i "http://$DNS/"
# Esperado: HTTP/1.1 200 OK, con el HTML de la Tienda de Perritos

# Probar la API del backend
curl -i "http://$DNS/api/productos"
# Esperado: HTTP/1.1 200 OK, con JSON de los productos

# Probar el health check
curl -i "http://$DNS/api/health"
# Esperado: {"status":"ok","message":"Backend de tienda de perritos en ejecucion."}
```

---

## 7. Detalles técnicos de cada componente

### 7.1. Módulo `network`

Provisiona toda la infraestructura de red:

| Recurso | Detalle |
|---------|---------|
| **VPC** | CIDR `10.0.0.0/20`, DNS support y hostnames habilitados |
| **Subnets públicas** (2) | `10.0.0.0/28` y `10.0.1.0/28` en `us-east-1a` y `us-east-1b`. Tag `kubernetes.io/role/elb = "1"` para NLBs internet-facing |
| **Subnets privadas-app** (2) | `10.0.2.0/28` y `10.0.3.0/28`. Tag `kubernetes.io/role/internal-elb = "1"` para NLBs internos |
| **Subnets privadas-data** (2) | `10.0.4.0/28` y `10.0.5.0/28`. Tag `kubernetes.io/role/internal-elb = "1"` |
| **Internet Gateway** | Conecta las subnets públicas a Internet |
| **NAT Gateway** | Con EIP en la primera subnet pública; permite salida a Internet desde las subnets privadas |
| **Tablas de ruteo** | Pública: ruta default vía IGW. Privada: ruta default vía NAT GW |

Todas las subnets tienen el tag `kubernetes.io/cluster/<cluster_name> = shared` para que EKS las reconozca como subnets del clúster.

### 7.2. Módulo `security_groups`

Crea dos security groups con reglas de ingress cruzadas:

**`eks-cluster-sg`** (del clúster):
- Ingress: todo el tráfico desde el CIDR de la VPC (`10.0.0.0/20`)
- Ingress: todo el tráfico desde el SG de los nodos
- Egress: todo el tráfico saliente

**`eks-nodes-sg`** (de los nodos worker):
- Ingress: todo el tráfico desde el SG del clúster
- Ingress: todo el tráfico desde sí mismo (comunicación inter-nodo)
- Ingress: puerto 80 desde `0.0.0.0/0` (tráfico HTTP del NLB)
- Ingress: puerto 3001 desde el CIDR de la VPC (backend)
- Ingress: puerto 3306 desde el CIDR de la VPC (MySQL)
- Egress: todo el tráfico saliente

### 7.3. Módulo `eks`

| Recurso | Detalle |
|---------|---------|
| **CloudWatch Log Group** | `/aws/eks/<name>/cluster`, retención 30 días, 5 tipos de log habilitados (api, audit, authenticator, controllerManager, scheduler) |
| **EKS Cluster** | Versión 1.30, endpoint público y privado, usa el rol `LabEksClusterRole` preexistente |
| **Node Group** | Instancias SPOT `t3.large`, escalado 1-3 nodos, en subnets públicas, usa el rol `LabEksNodeRole` preexistente |
| **Add-ons** | vpc-cni, amazon-cloudwatch-observability, metrics-server |

### 7.4. Módulo `ecr`

Crea tres repositorios ECR:

| Repositorio | Imagen | Descripción |
|-------------|--------|-------------|
| `tienda-frontend` | Nginx Alpine + HTML/JS | Servidor web estático con proxy reverso |
| `tienda-backend` | Node.js 18 Alpine + Express | API REST con conexión a MySQL |
| `tienda-db` | MySQL 8 con DB inicializada | Base de datos con datos semilla |

Todos los repositorios tienen:
- Mutabilidad de tags: **MUTABLE** (permite sobreescribir la misma etiqueta)
- Scan on push: **habilitado** (análisis de vulnerabilidades automático)

### 7.5. Recursos raíz adicionales

**Secret de Kubernetes (`aws-credentials`):**

El módulo raíz crea un Secret de Kubernetes en el namespace `kube-system` con las credenciales STS del estudiante. Este Secret se monta en el pod del LBC vía `envFrom`, lo que permite al controlador operar sin IRSA (IAM Roles for Service Accounts), que no está disponible en AWS Academy.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: kube-system
type: Opaque
data:
  AWS_ACCESS_KEY_ID: <base64>
  AWS_SECRET_ACCESS_KEY: <base64>
  AWS_SESSION_TOKEN: <base64>
```

**Helm Release del AWS LBC:**

Instalado con las siguientes opciones clave:
- `clusterName`, `region`, `vpcId` configurados desde outputs de Terraform
- `serviceAccount.create = true` (pero **sin** anotaciones IRSA)
- 1 réplica con límites de recursos (200m CPU, 256Mi memoria)
- `envFrom[0].secretRef.name = aws-credentials` (monta el Secret como variables de entorno)

### 7.6. Aplicación: backend (Node.js / Express)

**Archivo:** `app-k8s/backend/server.js`

API REST que corre en el puerto 3001 con las siguientes características:

- **Conexión a MySQL**: Usa `mysql2/promise` con un pool de conexiones configurado vía variables de entorno:
  - `DB_HOST` (default: `tienda-db`) — nombre del Service de Kubernetes
  - `DB_USER` (default: `root`)
  - `DB_PASSWORD` (default: `admin123`) — en K8s, se lee del Secret `mysql-secret`
  - `DB_NAME` (default: `tienda_perritos`)
  - `DB_PORT` (default: `3306`)

- **Endpoints**:
  - `GET /api/productos` — Lista todos los productos
  - `GET /api/productos/:id` — Obtiene un producto por ID
  - `POST /api/productos` — Crea un producto (requiere `nombre`, `precio`, `stock`)
  - `PUT /api/productos/:id` — Actualiza un producto
  - `DELETE /api/productos/:id` — Elimina un producto
  - `GET /api/health` — Health check (retorna `{"status":"ok","message":"Backend de tienda de perritos en ejecucion."}`)

- **CORS**: Habilitado para todos los orígenes
- **Deployment**: 2 réplicas con HPA (2-10 al 70% CPU), readiness probe en `/api/health` con delay de 5s, liveness probe con delay de 10s

### 7.7. Aplicación: frontend (Nginx + JS)

**Archivos:** `app-k8s/frontend/`

- **`index.html`**: Página HTML en español con título "Tienda de Alimentos para Perritos". Contiene una tabla de productos y un formulario para crear/editar productos.
- **`app.js`**: Lógica JavaScript del navegador que consume la API REST (`/api/productos`). Funciones: `cargarProductos()`, `guardarProducto()`, `editarProducto()`, `eliminarProducto()`.
- **`default.conf`**: Configuración de Nginx que:
  - Sirve contenido estático desde `/usr/share/nginx/html/`
  - Hace proxy reverso de `/api/` hacia `http://tienda-backend:3001`
  - Establece headers `X-Real-IP` y `X-Forwarded-For`

- **Deployment**: 2 réplicas con HPA (2-6 al 60% CPU), readiness probe en `/` con delay de 3s, liveness probe con delay de 10s
- **Service**: Tipo `LoadBalancer` con anotaciones para el AWS LBC (`aws-load-balancer-type: external`, `aws-load-balancer-scheme: internet-facing`)

### 7.8. Aplicación: base de datos (MySQL 8)

**Archivo:** `app-k8s/db/`

- **`Dockerfile`**: Basado en `mysql:8`, define las variables de entorno `MYSQL_ROOT_PASSWORD=admin123`, `MYSQL_DATABASE=tienda_perritos`, `MYSQL_USER=alumno`, `MYSQL_PASSWORD=alumno123`, y copia `init.sql` al directorio de inicialización.
- **`init.sql`**: Crea la tabla `productos` con columnas `id` (AUTO_INCREMENT), `nombre`, `descripcion`, `precio`, `stock`. Inserta 5 productos de ejemplo:
  1. Alimento Cachorro Premium — $19.990, stock 15
  2. Alimento Adulto Light — $17.990, stock 8
  3. Snacks Dentales — $5.990, stock 30
  4. Alimento Adulto Pedigree — $15.990, stock 40
  5. Bravery pollo Adulto raza pequeña — $25.990, stock 20

- **Deployment**: 1 réplica con volumen `emptyDir` en `/var/lib/mysql` (los datos se pierden al reiniciar el pod)
- **Service**: ClusterIP `None` (headless service), puerto 3306/TCP
- **Secret**: `mysql-secret` con `MYSQL_ROOT_PASSWORD` codificado en base64 (`YWRtaW4xMjM=` = "admin123")

---

## 8. Modelo de autenticación del LBC

En un clúster EKS estándar, el AWS Load Balancer Controller usa **IRSA** (IAM Roles for Service Accounts) para autenticarse contra la API de AWS. Sin embargo, **AWS Academy no permite crear roles IAM**, lo que hace IRSA inutilizable.

La solución implementada en este repositorio es:

1. Las credenciales STS del estudiante (`voclabs`) se almacenan en un **Secret de Kubernetes** (`aws-credentials` en `kube-system`).
2. El pod del LBC monta este Secret vía `envFrom`, inyectando las tres variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) directamente en el proceso.
3. No se configuran anotaciones IRSA en el ServiceAccount del LBC.

**Consecuencias de este modelo:**

- ✅ No requiere intervención del instructor para adjuntar políticas IAM.
- ✅ Funciona con los permisos que AWS Academy otorga al rol `voclabs`.
- ⚠️ Las credenciales STS **expiran cada ~3 horas**. Cuando expiran, es necesario:
  1. Re-exportar las credenciales: `source terraform/export_vars.sh`
  2. Re-aplicar el root `addons/`: `cd terraform/addons && terraform apply` (refresca el Secret)
  3. Reiniciar el pod del LBC: `kubectl -n kube-system rollout restart deploy/aws-load-balancer-controller`

---

## 9. Solución de problemas

### La sesión de AWS Academy expiró

**Síntoma:** Errores `ExpiredToken` o `AccessDenied` con `voc-cancel-cred` en cualquier operación de AWS.

**Solución:**

1. En Vocareum, haz clic en **Start Lab** y espera a que el indicador pase a verde.
2. Copia las nuevas credenciales del panel AWS Details.
3. Re-exporta las credenciales:
   ```bash
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
   source terraform/export_vars.sh
   ```
4. Re-aplica `addons/` para refrescar el Secret:
   ```bash
   cd terraform/addons
   terraform apply
   ```
5. Reinicia el pod del LBC:
   ```bash
   kubectl -n kube-system rollout restart deploy/aws-load-balancer-controller
   ```

### El Service `tienda-frontend` se queda en `<pending>`

**Causa más común:** El session token del LBC expiró. Verifica con:

```bash
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=20
# Si ves ExpiredToken → sigue los pasos de la sección anterior
```

### `terraform apply` falla con `AccessDenied` y `voc-cancel-cred`

Tu sesión del laboratorio fue cancelada o expiró. Reinicia el lab en Vocareum y re-exporta las credenciales.

### `terraform destroy` falla porque el NLB no se elimina

Si el pod del LBC ya no está corriendo, elimina manualmente:

```bash
# Verificar si el pod del LBC existe
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller

# Si el clúster ya fue destruido, eliminar manualmente en la consola AWS:
# EC2 → Load Balancers → selecciona el NLB k8s-... → Delete
# EC2 → Target Groups → elimina los target groups huérfanos
```

Luego re-ejecuta `terraform destroy`.

### Los roles `LabEksClusterRole-*` o `LabEksNodeRole-*` no se encuentran

Estos roles son pre-creados por el instructor del laboratorio. Verifica en la consola de AWS → IAM → Roles que existan. Si no existen, contacta al instructor.

Para más detalles, consulta `terraform/docs/TROUBLESHOOTING.es.md`.

---

## 10. Notas y advertencias importantes

1. **Credenciales temporales**: Las credenciales de AWS Academy expiran cada ~3 horas. Planifica re-exportar y re-aplicar si tu sesión de laboratorio es larga.

2. **Datos efímeros**: La base de datos MySQL usa un volumen `emptyDir`, lo que significa que **todos los datos se pierden al reiniciar el pod**. Esto es intencional para un entorno de laboratorio, pero no es apropiado para producción.

3. **Instancias SPOT**: El node group usa instancias SPOT (`t3.large`), que pueden ser interrumpidas por AWS con poca antelación. Si el node group falla al crearse, cambia `capacity_type` a `ON_DEMAND` en `terraform.tfvars`.

4. **No uses `LabRole` para EKS**: Usa siempre los roles dedicados `LabEksClusterRole-*` y `LabEksNodeRole-*`. `LabRole` tiene demasiados permisos y su trust policy no es la adecuada para EKS.

5. **URIs de imagen específicas de cuenta**: Los manifiestos de Kubernetes en `app-k8s/k8s/` contienen URIs de imagen con el ID de cuenta (`112769872808.dkr.ecr.us-east-1.amazonaws.com/...`). Si usas una cuenta diferente, necesitas actualizar estos URIs o usar `kubectl set image` después del despliegue.

6. **Contraseñas hardcodeadas**: El Dockerfile de MySQL contiene contraseñas en texto plano (`MYSQL_ROOT_PASSWORD=admin123`, `MYSQL_USER=alumno`, `MYSQL_PASSWORD=alumno123`). En un entorno de producción, estas deberían venir de Kubernetes Secrets.

7. **El archivo `terraform.tfstate` contiene información sensible**: Incluye el endpoint del clúster EKS, el ID de cuenta AWS y otros detalles de infraestructura. En un entorno real, este archivo debería almacenarse en un backend remoto cifrado (por ejemplo, S3 con cifrado del lado del servidor) y nunca committearse al repositorio.

8. **El script `export_vars.sh` contiene credenciales reales**: En un entorno de producción, este archivo debería estar en `.gitignore` y nunca committearse. Para el laboratorio, asegúrate de no compartirlo fuera de tu equipo.

9. **Tiempo de creación del clúster**: EKS toma ~10-15 minutos en crear el clúster y ~5-10 minutos adicionales para el node group. El despliegue total toma aproximadamente 20 minutos.

10. **Los `.gitignore` de `terraform/cluster/` y `terraform/addons/` excluyen archivos sensibles**: Los archivos `terraform.tfstate`, `terraform.tfvars`, `.terraform.lock.hcl` y `.terraform/` están en `.gitignore` para que no se commiteen. Asegúrate de que ningún `terraform.tfvars` con credenciales reales llegue al repositorio.

---

## 11. Estructura del repositorio

```
github-repo/
│
├── README.md                          # Este documento
│
├── app-k8s/                           # Aplicación contenerizada + manifiestos K8s
│   ├── Makefile                       # Automatización de build/tag/push a ECR
│   ├── backend/                       # API REST Node.js
│   │   ├── Dockerfile                 # Imagen Node.js 18 Alpine
│   │   ├── server.js                 # Código del servidor Express
│   │   └── package.json              # Dependencias (express, cors, mysql2)
│   ├── frontend/                      # Interfaz web Nginx
│   │   ├── Dockerfile                 # Imagen Nginx Alpine
│   │   ├── app.js                     # Lógica CRUD del navegador
│   │   ├── index.html                # Página HTML de la tienda
│   │   └── default.conf              # Configuración de Nginx (proxy /api/)
│   ├── db/                            # Base de datos MySQL
│   │   ├── Dockerfile                 # Imagen MySQL 8 con DB inicializada
│   │   └── init.sql                   # Esquema y datos semilla
│   └── k8s/                           # Manifiestos de Kubernetes
│       ├── namespace.yaml             # Namespace "tienda"
│       ├── mysql-secret.yaml          # Secret con contraseña de MySQL
│       ├── mysql-deployment.yaml      # Deployment de MySQL (1 réplica)
│       ├── mysql-service.yaml         # Service headless para MySQL
│       ├── backend-deployment.yaml    # Deployment del backend (2 réplicas)
│       ├── backend-service.yaml       # Service ClusterIP puerto 3001
│       ├── backend-hpa.yaml           # HPA backend 2-10 réplicas 70% CPU
│       ├── frontend-deployment.yaml   # Deployment del frontend (2 réplicas)
│       ├── frontend-service.yaml      # Service LoadBalancer (NLB público)
│       ├── frontend-hpa.yaml          # HPA frontend 2-6 réplicas 60% CPU
│       └── README.txt                 # Instrucciones de despliegue
│
└── terraform/                          # Infraestructura como código (Terraform)
    ├── cluster/                        # Root 1: AWS-only (VPC, SGs, EKS, ECR)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── versions.tf                 # Solo providers aws (+ external)
    │   ├── terraform.tfvars.example
    │   └── .gitignore
    ├── addons/                         # Root 2: kubernetes/helm (LBC, Secret)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── versions.tf                 # providers aws + kubernetes + helm + external
    │   ├── terraform.tfvars.example
    │   └── .gitignore
    ├── export_vars.sh                  # Script de exportación de credenciales AWS
    ├── docs/                           # README, RUNBOOK, TROUBLESHOOTING (en/es)
    ├── modules/                        # Módulos compartidos por ambos roots
    │   ├── network/                    # VPC, subnets, IGW, NAT GW, route tables
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   └── outputs.tf
    │   ├── security_groups/            # SG del clúster y de los nodos
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   └── outputs.tf
    │   ├── eks/                       # Clúster EKS, node group, add-ons
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   └── outputs.tf
    │   └── ecr/                       # Repositorios ECR
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
```

---

> **Laboratorio de duoc/intro-devops** — Infraestructura EKS + aplicación Tienda de Perritos. Diseñado para AWS Academy con Terraform, Kubernetes y Docker.
