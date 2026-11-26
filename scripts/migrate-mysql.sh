#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Migration MySQL : Docker Compose vers Kubernetes ==="

: "${MYSQL_ROOT_PASSWORD:?La variable MYSQL_ROOT_PASSWORD est obligatoire}"

# Vérifier les outils nécessaires
command -v kubectl >/dev/null 2>&1 || {
    echo "ERREUR : kubectl est introuvable"
    exit 1
}

command -v docker >/dev/null 2>&1 || {
    echo "ERREUR : docker est introuvable"
    exit 1
}

# Vérifier que la base source est démarrée
if [[ "$(docker inspect -f '{{.State.Running}}' appgestion-db 2>/dev/null || true)" != "true" ]]; then
    echo "ERREUR : le conteneur appgestion-db n'est pas démarré"
    exit 1
fi

# Attendre que MySQL Kubernetes soit disponible
echo "Attente de MySQL dans Kubernetes..."

for attempt in $(seq 1 30); do
    if kubectl exec mysql-0 -- sh -c \
        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin -h 127.0.0.1 -uroot ping --silent' \
        >/dev/null 2>&1; then
        break
    fi

    if [[ "$attempt" -eq 30 ]]; then
        echo "ERREUR : MySQL Kubernetes n'est pas disponible"
        exit 1
    fi

    sleep 5
done

# Compter les tables de la base source
SOURCE_TABLE_COUNT=$(
    docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" appgestion-db \
        mysql -h 127.0.0.1 -uroot -Nse \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='test_db'"
)

# Compter les tables de la base Kubernetes
TARGET_TABLE_COUNT=$(
    kubectl exec mysql-0 -- sh -c \
        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h 127.0.0.1 -uroot -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''test_db'\''"'
)

echo "Tables dans Docker Compose : $SOURCE_TABLE_COUNT"
echo "Tables dans Kubernetes    : $TARGET_TABLE_COUNT"

if [[ "$SOURCE_TABLE_COUNT" -eq 0 ]]; then
    echo "ERREUR : la base source test_db est vide"
    exit 1
fi

# Ne jamais écraser une base Kubernetes déjà initialisée
if [[ "$TARGET_TABLE_COUNT" -gt 0 ]]; then
    if [[ "$TARGET_TABLE_COUNT" -eq "$SOURCE_TABLE_COUNT" ]]; then
        echo "La base Kubernetes contient déjà $TARGET_TABLE_COUNT tables."
        echo "Migration ignorée : aucune donnée ne sera écrasée."
        exit 0
    fi

    echo "ERREUR : la base Kubernetes n'est pas vide et son nombre de tables diffère de la source."
    echo "Migration interrompue pour protéger les données existantes."
    exit 1
fi

# Exporter la base source
DUMP_FILE=$(mktemp)
trap 'rm -f "$DUMP_FILE"' EXIT

echo "Export de la base test_db depuis Docker Compose..."

docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" appgestion-db \
    mysqldump -h 127.0.0.1 -uroot \
    --single-transaction --routines --triggers \
    --no-tablespaces test_db > "$DUMP_FILE"

if [[ ! -s "$DUMP_FILE" ]]; then
    echo "ERREUR : le fichier dump est vide"
    exit 1
fi

# Importer dans Kubernetes
echo "Import de la base test_db dans Kubernetes..."

kubectl exec -i mysql-0 -- sh -c \
    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h 127.0.0.1 -uroot test_db' \
    < "$DUMP_FILE"

# Vérifier le résultat
FINAL_TABLE_COUNT=$(
    kubectl exec mysql-0 -- sh -c \
        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h 127.0.0.1 -uroot -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''test_db'\''"'
)

if [[ "$FINAL_TABLE_COUNT" -ne "$SOURCE_TABLE_COUNT" ]]; then
    echo "ERREUR : vérification échouée après import."
    echo "Source : $SOURCE_TABLE_COUNT tables ; Kubernetes : $FINAL_TABLE_COUNT tables"
    exit 1
fi

echo "Migration terminée avec succès."
echo "Nombre de tables importées : $FINAL_TABLE_COUNT"
