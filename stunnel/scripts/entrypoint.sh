#!/bin/sh
set -e

/usr/local/bin/generate-cert.sh

exec stunnel /etc/stunnel/stunnel.conf

