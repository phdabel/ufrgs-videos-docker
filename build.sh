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

if [ "$(ls -A $CERTS_PATH | wc -l)" -le 1 ]
then

    # generating ssl key and certificate
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/C=BR/ST=Rio Grande do Sul/L=Porto Alegre/O=UFRGS/OU=CPD/CN=videos.dev" \
    -keyout "$CERTS_PATH"dev-app.key -out "$CERTS_PATH"dev-app.crt

    # generating DH key
    sudo openssl dhparam -out "$CERTS_PATH"dhparam.pem 2048
fi

if [ ! -z $1 ]
then
    # create the build
    if [ $1 = "create" ]
    then

        sudo docker-compose up -d --build
        sudo docker-compose run --rm -w "$CONTAINER_APP_DIR" php composer install
        sudo docker-compose run --rm -w "$CONTAINER_APP_DIR" php ./init --env=Development --overwrite=All
    fi

    # starts the build (default value)
    if [ $1 = "start" ]
    then
        sudo docker-compose up -d
    fi

    # stops the build
    if [ $1 = "stop" ]
    then
        sudo docker-compose down --remove-orphans
    fi

    # stops and clean images and containers
    if [ $1 = "clean" ]
    then
        sudo docker-compose down --remove-orphans
        # force cleaning
        if [ ! -z $2 ] && [ $2 = "--force" ]
        then
            sudo docker system prune -af
        else
            sudo docker sytem prune -a
        fi
    fi
else
    sudo docker-compose up -d
fi


if [ ! "$(ls -A $DB_PATH)" ]
then
    sleep 5
    sudo docker-compose run --rm -w "$CONTAINER_APP_DIR" php ./yii migrate --interactive=0
fi

sudo docker exec -it yii2fpm_php_1 service supervisor stop
sudo docker exec -it yii2fpm_php_1 service supervisor start
#sudo docker-compose run --rm -w "${CONTAINER_APP_DIR}" php php -d error_reporting="E_ALL ^ E_DEPRECATED" vendor/bin/phpunit frontend/tests --exclude db
