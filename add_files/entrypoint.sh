#!/bin/sh

/generator.sh
exec /usr/sbin/named -u named -c /etc/bind/named.conf -g
