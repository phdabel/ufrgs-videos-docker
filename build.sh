#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

export HOST_APP_DIR=_host-volumes/app/
export CONTAINER_APP_DIR=/opt/app/
export CERTS_PATH=php/etc/nginx/certs/
export DB_PATH=_host-volumes/db/data/

if [ ! "$(ls -A $HOST_APP_DIR)" ]
then
    echo -e "${RED}O diretório da aplicação está vazio.${NC}"
    cp .env-dist .env
    git clone https://gitlab.cpd.ufrgs.br/teamvideos/ufrgs-videos.git "${HOST_APP_DIR}"
fi

if [ ! "$(ls -A $CERTS_PATH)" ]
then

    # generating ssl key and certificate
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/C=BR/ST=Rio Grande do Sul/L=Porto Alegre/O=UFRGS/OU=CPD/CN=videos.dev" \
    -keyout "$CERTS_PATH"dev-app.key -out "$CERTS_PATH"dev-app.crt

    # generating DH key
    sudo openssl dhparam -out "$CERTS_PATH"dhparam.pem 2048
fi

sudo docker-compose up -d --build
sudo docker-compose run --rm -w "$CONTAINER_APP_DIR" php composer install
sudo docker-compose run --rm -w "$CONTAINER_APP_DIR" php ./init --env=Development --overwrite=All

if [ ! "$(ls -A $DB_PATH)" ]
then
    sleep 5
    sudo docker-compose run --rm -w "$CONTAINER_APP_DIR" php ./yii migrate --interactive=0
fi

sudo docker exec -it yii2fpm_php_1 service supervisor stop
sudo docker exec -it yii2fpm_php_1 service supervisor start
#sudo docker-compose run --rm -w "${CONTAINER_APP_DIR}" php php -d error_reporting="E_ALL ^ E_DEPRECATED" vendor/bin/phpunit frontend/tests --exclude db
