#!/bin/bash

function check_figlet {
    echo "Verificando paquetes, por favor espera..."
    sleep 1
    if ! command -v figlet &> /dev/null; then
        echo "figlet no está instalado. Instalando..."
        sleep 1
        sudo apt update
        sudo apt install -y figlet
    elif ! figlet "test" &> /dev/null; then
        echo "figlet no funciona correctamente, instalando..."
        sudo apt install --reinstall -y figlet 
    fi
    sudo apt install hostapd dnsmasq -y
    echo "Paquetes instalados. Continuando..."
    sleep 2
}

function inicio {
    # Definir colores
    RED=$(tput setaf 1)
    RESET=$(tput sgr0)
    clear
    check_figlet
    echo "======================================================================"
    figlet "Iniciando script"
    echo "======================================================================"
    sleep 2
    
    clear
    sleep 1
    echo "${RED}=============================================================="
    echo "${RED}=============================================================="
    figlet -f big "Access Point : )" 
    echo "${RED}=============================================================="
    echo "==============================================================${RESET}"
    sleep 1
}

function animacionCarga {
    
    spin='|/-\'
    spinners=()
    num_spinners=5  
    duration=3 

    for ((j=0; j<num_spinners; j++)); do
        spinners[j]=0
    done
    end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        printf "\r"
        for ((j=0; j<num_spinners; j++)); do
            printf ${spin:spinners[j]++%${#spin}:1}
            if [ "${spinners[j]}" -ge 20 ]; then
                spinners[j]=0
            fi
        done
        sleep 0.1
    done
    printf "\n" 
	 
}


# Obtener funcion de usuarios
function obtenerInterfaces {
    
    interfaces=$(ip -o link show | awk -F': ' '{print $2}')
    echo "Las interfaces disponibles son:"
    echo "$interfaces"
    
    echo "Interfaz que se usará como AP: "
    read interfazParaAP
    sleep 0.2
    echo "Interfaz que se conectará al internet: "
    read interfazConInternet
    sleep 0.2
    echo "Configurando interfaces..."
    animacionCarga
    echo "Interfaz que se usará como AP: $interfazParaAP"
    sleep 0.2
    echo "Interfaz que se conectará a Internet: $interfazConInternet"
    sleep 0.5
    echo "Presiona enter para continuar."
    read
    clear
}

function editarHostpad {
    
    sudo ip link set $interfazParaAP down
    sudo sysctl -w net.ipv4.ip_forward=1
    echo "Configurando /etc/hostapd/hostapd.conf..."
    sudo rm /etc/hostapd/hostapd.conf
    animacionCarga
    echo "Nombre de la red del AP: "
    read nombreSSID
    echo "Contraseña de la red: "
    read nombreContrasena
    sudo bash -c "cat > /etc/hostapd/hostapd.conf << EOF 
interface=$interfazParaAP
driver=nl80211
ssid=$nombreSSID
hw_mode=g
channel=6
wmm_enabled=0
auth_algs=1
wpa=2
wpa_passphrase=$nombreContrasena
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF"
    echo "Configuración guardada en /etc/hostapd/hostapd.conf."
    sleep 0.2
    sudo ip link set $interfazParaAP up
    animacionCarga
    echo -e "[keyfile]\nunmanaged-devices=interface-name:$interfazParaAP" | sudo tee /etc/NetworkManager/conf.d/ignore-wifi.conf
    sudo ip addr flush dev $interfazParaAP
    sudo ip addr add 192.168.50.1/24 dev $interfazParaAP
    echo "Interfaz $interfazParaAP activada para uso de AP."
    animacionCarga
    echo "presiona enter para continuar"
    read
    clear
}

function editarDnsmasq  {
    
    echo "Configurando /etc/dnsmasq.conf..."
    sudo rm /etc/dnsmasq.conf    
    sudo bash -c "cat > /etc/dnsmasq.conf << EOF
interface=$interfazParaAP
dhcp-range=192.168.50.10,192.168.50.100,12h
# Establecer DNS a la IP local
dhcp-option=6,192.168.50.1
# Permitir redirección DNS
# address=/#/192.168.50.1
EOF"
    sleep 0.8
    echo "Configuración de dnsmasq completada :)"
    animacionCarga
    clear
}

function agregarIptables {
    
    echo "Agregando reglas en iptables..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080
    sudo iptables -t nat -A POSTROUTING -o $interfazConInternet -j MASQUERADE
    sudo iptables -A FORWARD -i $interfazConInternet -o $interfazParaAP -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i $interfazParaAP -o $interfazConInternet -j ACCEPT
    animacionCarga
    echo "Listo."
    echo "Presiona enter para continuar"
    read
    clear
}

function abrirProxy {
    sleep 1
    echo "${RED}=============================================================="
    echo "${RED}=============================================================="
    figlet -f big "mitmproxy" 
    echo "${RED}=============================================================="
    echo "==============================================================${RESET}"
    sleep 1.5
    mate-terminal -- bash -c "sudo mitmproxy --mode transparent"
}


function crearAP {
    inicio
    obtenerInterfaces
    editarHostpad
    editarDnsmasq
    agregarIptables
    sudo systemctl restart hostapd dnsmasq
    echo "Punto de acceso configurado y mitmproxy iniciando...."
    animacionCarga
    abrirProxy
}

crearAP
