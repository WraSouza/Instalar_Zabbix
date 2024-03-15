#!/bin/bash

echo "Atualizando o Servidor"
echo "----------------------"
sudo apt-get update
sudo apt-get upgrade -y

echo "Instalando o CURL"
echo "----------------------"
sudo apt-get install curl -y

echo "Instalando o Docker"
echo "----------------------"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "Criando a Rede do Docker"
echo "----------------------"
sudo docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 zabbix-net

echo "Criando Uma Instância do Postgre"
echo "----------------------"
sudo docker run --name postgres-server -t -e POSTGRES_USER="zabbix" -e POSTGRES_PASSWORD="zabbix_pwd" -e POSTGRES_DB="zabbix" --network=zabbix-net --restart unless-stopped -d postgres:latest

echo "Iniciando Zabbix SNMTP"
echo "----------------------"
sudo docker run --name zabbix-snmptraps -t -v /zbx_instance/snmptraps:/var/lib/zabbix/snmptraps:rw -v /var/lib/zabbix/mibs:/usr/share/snmp/mibs:ro --network=zabbix-net -p 162:1162/udp --restart unless-stopped -d zabbix/zabbix-snmptraps:alpine-6.4-latest

echo "Iniciando Zabbix Server e Linkando com o PostGre"
echo "----------------------"
docker run --name zabbix-server-pgsql -t \
      -e DB_SERVER_HOST="postgres-server" \
      -e POSTGRES_USER="zabbix" \
      -e POSTGRES_PASSWORD="zabbix_pwd" \
      -e POSTGRES_DB="zabbix" \
      -e ZBX_ENABLE_SNMP_TRAPS="true" \
      --network=zabbix-net \
      -p 10051:10051 \
      --volumes-from zabbix-snmptraps \
      --restart unless-stopped \
      -d zabbix/zabbix-server-pgsql:alpine-6.4-latest

echo "Iniciando Zabbix Web Interface"
echo "----------------------"
      docker run --name zabbix-web-nginx-pgsql -t \
      -e ZBX_SERVER_HOST="zabbix-server-pgsql" \
      -e DB_SERVER_HOST="postgres-server" \
      -e POSTGRES_USER="zabbix" \
      -e POSTGRES_PASSWORD="zabbix_pwd" \
      -e POSTGRES_DB="zabbix" \
      --network=zabbix-net \
      -p 443:8443 \
      -p 80:8080 \
      -v /etc/ssl/nginx:/etc/ssl/nginx:ro \
      --restart unless-stopped \
      -d zabbix/zabbix-web-nginx-pgsql:alpine-6.4-latest