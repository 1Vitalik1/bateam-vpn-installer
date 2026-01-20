#!/bin/bash
set -e

echo "==================================="
echo "DPI Bypass (Zapret) Starting"
echo "==================================="

# Переменные окружения
MODE=${MODE:-tpws}  # tpws или nfqws
TPWS_PORT=${TPWS_PORT:-988}
NFQWS_QUEUE=${NFQWS_QUEUE:-200}
ENABLE_IPV6=${ENABLE_IPV6:-false}

# Аргументы для tpws (прозрачный прокси)
TPWS_ARGS=${TPWS_ARGS:-"--split-pos=2 --split-http-req=method --disorder --oob"}

# Аргументы для nfqws (netfilter queue)
NFQWS_ARGS=${NFQWS_ARGS:-"--dpi-desync=split2 --dpi-desync-ttl=5 --dpi-desync-fooling=badseq"}

echo "Mode: $MODE"
echo "IPv6 enabled: $ENABLE_IPV6"

# Загрузка модулей ядра
modprobe iptable_nat 2>/dev/null || true
modprobe nf_conntrack 2>/dev/null || true
modprobe nfnetlink_queue 2>/dev/null || true

# Функция очистки при завершении
cleanup() {
    echo "Cleaning up iptables rules..."
    iptables -t nat -D PREROUTING -i tun+ -p tcp --dport 80 -j REDIRECT --to-port $TPWS_PORT 2>/dev/null || true
    iptables -t nat -D PREROUTING -i tun+ -p tcp --dport 443 -j REDIRECT --to-port $TPWS_PORT 2>/dev/null || true
    iptables -t mangle -D PREROUTING -i tun+ -p tcp --dport 80 -j NFQUEUE --queue-num $NFQWS_QUEUE 2>/dev/null || true
    iptables -t mangle -D PREROUTING -i tun+ -p tcp --dport 443 -j NFQUEUE --queue-num $NFQWS_QUEUE 2>/dev/null || true
    
    if [ "$ENABLE_IPV6" = "true" ]; then
        ip6tables -t nat -D PREROUTING -i tun+ -p tcp --dport 80 -j REDIRECT --to-port $TPWS_PORT 2>/dev/null || true
        ip6tables -t nat -D PREROUTING -i tun+ -p tcp --dport 443 -j REDIRECT --to-port $TPWS_PORT 2>/dev/null || true
        ip6tables -t mangle -D PREROUTING -i tun+ -p tcp --dport 80 -j NFQUEUE --queue-num $NFQWS_QUEUE 2>/dev/null || true
        ip6tables -t mangle -D PREROUTING -i tun+ -p tcp --dport 443 -j NFQUEUE --queue-num $NFQWS_QUEUE 2>/dev/null || true
    fi
    
    pkill -9 tpws 2>/dev/null || true
    pkill -9 nfqws 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# Ожидание появления TUN интерфейса
echo "Waiting for TUN interface..."
for i in {1..30}; do
    if ip link show | grep -q "tun"; then
        echo "TUN interface detected"
        break
    fi
    sleep 1
done

if [ "$MODE" = "tpws" ]; then
    echo "Starting TPWS mode..."
    echo "Arguments: $TPWS_ARGS"
    
    # Настройка iptables для перенаправления трафика на tpws
    iptables -t nat -A PREROUTING -i tun+ -p tcp --dport 80 -j REDIRECT --to-port $TPWS_PORT
    iptables -t nat -A PREROUTING -i tun+ -p tcp --dport 443 -j REDIRECT --to-port $TPWS_PORT
    
    if [ "$ENABLE_IPV6" = "true" ]; then
        ip6tables -t nat -A PREROUTING -i tun+ -p tcp --dport 80 -j REDIRECT --to-port $TPWS_PORT
        ip6tables -t nat -A PREROUTING -i tun+ -p tcp --dport 443 -j REDIRECT --to-port $TPWS_PORT
    fi
    
    # Запуск tpws
    echo "Starting tpws on port $TPWS_PORT..."
    /opt/zapret/tpws/tpws \
        --port=$TPWS_PORT \
        --user=nobody \
        --bind-addr=0.0.0.0 \
        $TPWS_ARGS &
    
    TPWS_PID=$!
    echo "TPWS started with PID: $TPWS_PID"
    
elif [ "$MODE" = "nfqws" ]; then
    echo "Starting NFQWS mode..."
    echo "Arguments: $NFQWS_ARGS"
    
    # Настройка iptables для отправки пакетов в NFQUEUE
    iptables -t mangle -A PREROUTING -i tun+ -p tcp --dport 80 -j NFQUEUE --queue-num $NFQWS_QUEUE
    iptables -t mangle -A PREROUTING -i tun+ -p tcp --dport 443 -j NFQUEUE --queue-num $NFQWS_QUEUE
    
    if [ "$ENABLE_IPV6" = "true" ]; then
        ip6tables -t mangle -A PREROUTING -i tun+ -p tcp --dport 80 -j NFQUEUE --queue-num $NFQWS_QUEUE
        ip6tables -t mangle -A PREROUTING -i tun+ -p tcp --dport 443 -j NFQUEUE --queue-num $NFQWS_QUEUE
    fi
    
    # Запуск nfqws
    echo "Starting nfqws on queue $NFQWS_QUEUE..."
    /opt/zapret/nfq/nfqws \
        --qnum=$NFQWS_QUEUE \
        --user=nobody \
        $NFQWS_ARGS &
    
    NFQWS_PID=$!
    echo "NFQWS started with PID: $NFQWS_PID"
fi

# Вывод статистики iptables
echo ""
echo "Active iptables rules:"
iptables -t nat -L PREROUTING -n -v | grep -E "REDIRECT|tun" || echo "No NAT rules"
iptables -t mangle -L PREROUTING -n -v | grep -E "NFQUEUE|tun" || echo "No mangle rules"

echo ""
echo "DPI Bypass is running. Logs will appear below:"
echo "==================================="

# Мониторинг процесса
while true; do
    if [ "$MODE" = "tpws" ]; then
        if ! kill -0 $TPWS_PID 2>/dev/null; then
            echo "TPWS процесс завершился, перезапуск..."
            cleanup
            exit 1
        fi
    elif [ "$MODE" = "nfqws" ]; then
        if ! kill -0 $NFQWS_PID 2>/dev/null; then
            echo "NFQWS процесс завершился, перезапуск..."
            cleanup
            exit 1
        fi
    fi
    sleep 10
done