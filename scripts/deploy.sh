#!/bin/bash

# scripts/deploy.sh

# Variables d'environnement
ENV=${1:-staging}
REGISTRY=${CI_REGISTRY:-localhost:5000}
IMAGE_TAG=${CI_COMMIT_SHA:-latest}

# Fonction pour vérifier la santé des services
check_health() {
    local service=$1
    local max_attempts=30
    local attempt=1

    echo "Vérification de la santé du service $service..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://$service/health" > /dev/null; then
            echo "Service $service est en bonne santé"
            return 0
        fi
        echo "Tentative $attempt/$max_attempts..."
        sleep 5
        attempt=$((attempt + 1))
    done
    echo "Le service $service n'est pas en bonne santé après $max_attempts tentatives"
    return 1
}

# Fonction pour déployer un service
deploy_service() {
    local service=$1
    echo "Déploiement du service $service..."
    
    # Pull de l'image
    docker pull $REGISTRY/$service:$IMAGE_TAG
    
    # Mise à jour du service
    docker service update --image $REGISTRY/$service:$IMAGE_TAG e-commerce_$service
    
    # Vérification de la santé
    check_health $service
}

# Déploiement des services
echo "Déploiement en environnement $ENV..."

# Déploiement de la base de données
echo "Déploiement de MongoDB..."
docker stack deploy -c docker-compose.$ENV.yml e-commerce

# Attente que MongoDB soit prêt
sleep 10

# Déploiement des services dans l'ordre
deploy_service "auth-service"
deploy_service "product-service"
deploy_service "order-service"
deploy_service "frontend"

echo "Déploiement terminé !"
