#!/bin/bash

# Set Vars
GLUETUN_API_URL=${GLUETUN_API_URL}
QBITTORRENT_URL=${QBITTORRENT_URL}
QBITTORRENT_USERNAME=${QBITTORRENT_USERNAME}
QBITTORRENT_PASSWORD=${QBITTORRENT_PASSWORD}

# Check if variables are set
if [ -z $GLUETUN_API_URL ]; then
    echo "GLUETUN_API_URL is not set"
    exit 1
fi

if [ -z "$QBITTORRENT_URL" ]; then
    echo "QBITTORRENT_URL is not set"
    exit 1
fi

if [ -z "$QBITTORRENT_USERNAME" ]; then
    echo "QBITTORRENT_USERNAME is not set"
    exit 1
fi

if [ -z "$QBITTORRENT_PASSWORD" ]; then
    echo "QBITTORRENT_PASSWORD is not set"
    exit 1
fi

#get previously set Port
if [ -f /tmp/gluetun_response.json ]; then
    gluetun_forwarded_port_old=$(grep -o '"port":[0-9]*' /tmp/gluetun_response.json | grep -o '[0-9]*')
else
    gluetun_forwarded_port_old=0
    echo "No old port found"
fi

# Get Port forwarded from Gluetun control server
gluetun_response=$(curl -s -w "%{http_code}" -o /tmp/gluetun_response.json ${GLUETUN_API_URL}/v1/openvpn/portforwarded)
gluetun_response_code=$(echo "$gluetun_response" | tail -n1)
gluetun_response_body=$(echo "$gluetun_response" | head -n-1)

if [ "$gluetun_response_code" -ne 200 ]; then
    echo "Failed to get forwarded port"
    exit 1
else
    gluetun_forwarded_port=$(grep -o '"port":[0-9]*' /tmp/gluetun_response.json | grep -o '[0-9]*')
    echo "Forwarded port is $gluetun_forwarded_port"
fi

if [ "$gluetun_forwarded_port" -eq "$gluetun_forwarded_port_old" ]; then
    echo "Port from file is the same as before, no change needed"
    exit 1
else
    # Login-data for qBittorrent
    login_data="username=${QBITTORRENT_USERNAME}&password=${QBITTORRENT_PASSWORD}"

    # Llog in to qBittorrent and save cookie
    login_response=$(curl -s -c /tmp/qbit_cookie.txt -w "%{http_code}" -o /tmp/qbit_login_response.txt --data $login_data ${QBITTORRENT_URL}/api/v2/auth/login)
    login_response_code=$(echo  "$login_response" | tail -n1)

    if [ "$login_response_code" -ne 200 ]; then
        echo "Qbittorrent login failed"
        exit 1
    else
        # get current listen port
        preferences_response=$(curl -s -b /tmp/qbit_cookie.txt -w "%{http_code}" -o /tmp/qbit_preferences_response.json ${QBITTORRENT_URL}/api/v2/app/preferences)
        preferences_response_code=$(echo "$preferences_response" | tail -n1)

        if [ "$preferences_response_code" -ne 200 ]; then
            echo "Failed to get current preferences"
            exit 1
        else
            current_listen_port=$(grep -o '"listen_port":[0-9]*' /tmp/qbit_preferences_response.json | grep -o '[0-9]*')
            echo "Current listen port is $current_listen_port"
            
            if [ "$current_listen_port" -eq "$gluetun_forwarded_port" ]; then
                echo "Port from settings is already the same, no change needed"
            else
                # Set new listen port
                port_data="{\"listen_port\": ${gluetun_forwarded_port}}"
                set_preference_response=$(curl -s -b /tmp/qbit_cookie.txt -w "%{http_code}" -o /tmp/qbit_set_preference_response.txt --data "json=$port_data" ${QBITTORRENT_URL}/api/v2/app/setPreferences)
                set_preference_response_code=$(echo "$set_preference_response" | tail -n1)

                if [ "$set_preference_response_code" -ne 200 ]; then
                    echo "Port forwarding failed"
                    exit 1
                else
                    echo "Forwarded port changed successfully"
                fi
            fi
        fi

        # Logout from qBittorrent
        curl -s -b /tmp/qbit_cookie.txt ${QBITTORRENT_URL}/api/v2/auth/logout > /dev/null
    fi
fi

