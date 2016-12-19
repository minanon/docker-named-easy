#!/bin/sh

# bind conf dirs
bind_conf_dir=/etc/bind
bind_conf_file=${bind_conf_dir}/named.conf
bind_directory=/etc/bind/data


# generator conf
conf_file=/generator/configs/generator.conf
template_dir=/generator/templates
global_tmpl_file=${template_dir}/global.tmpl
zone_tmpl_file=${template_dir}/zone.tmpl
subdomain_tmpl_file=${template_dir}/subdomain.tmpl
zone_conf_tmpl_file=${template_dir}/zone_conf.tmpl
zone_conf_norip_tmpl_file=${template_dir}/zone_conf_norip.tmpl

# global vars
mynet=$(ip -o -4 a | grep -v ': lo' | awk 'NR == 1{print $4}')
myaddr=${mynet%/*}
myacl=""
email="your.email.address"
servername="mydns.local"
forwarders="8.8.8.8;208.67.222.123"

# zone vars
zone_ttl=7200
zone_refresh=28800
zone_retry=1800
zone_expire=604800
zone_minimum=86400
zone_serial=0

root_url="https://www.internic.net/domain/named.root"

# remove exists files
clear_data(){
    rm -rf ${bind_conf_file} ${bind_directory}/*
}


# global settings
global_setting(){
    eval "echo \"$(cat ${global_tmpl_file})\"" > ${bind_conf_file}
}
global_conf(){
    local var=${1%% *}
    local val=$(echo "${1#* }" | sed -e 's/^ \+\| \+$//g' )
    eval "${var}='${val}'"
    case "${var}" in
        acl)
            myacl="${acl%;};"
            ;;
        forwarders)
            forwarders=${forwarders%;}
            ;;
    esac
}

# hint settings
hint_setting(){
    local hint_file_name=named.root
    local hint_file=${bind_directory}/${hint_file_name}
    wget -q "${root_url}" -O ${hint_file}
    cat <<EOS >> ${bind_conf_file}
zone "." IN {
    type hint;
    file "${hint_file_name}";
};
EOS
}

# zone settings
create_record(){
    local subname=$1
    local kind=$2
    local ip="${3:-$base_ip}"
    [ "${4}" ] && ip="${ip} ${4}"
    eval "echo \"$(cat ${subdomain_tmpl_file})\""
}
subdomain_conf(){
    echo "${subdomains}" | sed -e 's/ *, */\n/g' | while read -r sub
    do
        eval "create_record $(echo "${sub}" | sed -e 's/\*/"*"/')"
    done
}
ptr_conf(){
    create_record ' ' PTR "${domain}"
    echo "${subdomains}" | sed -e 's/ *, */\n/g' | while read -r sub
    do
        local subdomain=$(echo "${sub}" | cut -f1 -d' ')
        [ "${subdomain}" != '@' ] && [ "${subdomain}" != '*' ] &&
            create_record ' ' PTR "${subdomain}.${domain}"
    done
}
zone_setting(){
    local domain=$1
    local base_ip=$2
    local subdomains=$3
    local ttl=${4:-$zone_ttl}
    local refresh=${5:-$zone_refresh}
    local retry=${6:-$zone_retry}
    local expire=${7:-$zone_expire}
    local minimum=${8:-$zone_minimum}
    zone_serial=$(( $zone_serial + 1 ))
    local rip=$(echo "${base_ip}" | sed 's/\(\d\+\)\.\(\d\+\)\.\(\d\+\)\.\(\d\+\)/\4.\3.\2.\1/')

    # domain zone
    local subdomain=$(subdomain_conf)
    eval "echo \"$(cat ${zone_tmpl_file})\"" > ${bind_directory}/${domain}.zone

    zone_serial=$(( $zone_serial + 1 ))
    # ptr zone
    local subdomain=$(ptr_conf)
    local rzone_file=${bind_directory}/${rip}.zone
    local exist_rip=false
    if [ -f "${rzone_file}" ]
    then
        exist_rip=true
        echo "${subdomain}" >> ${rzone_file}
    else
        eval "echo \"$(cat ${zone_tmpl_file})\"" > ${rzone_file}
    fi

    # add
    if ${exist_rip}
    then
        local target=${zone_conf_norip_tmpl_file}
    else
        local target=${zone_conf_tmpl_file}
    fi
    eval "echo \"$(cat ${target})\"" >> ${bind_conf_file}
}

# setting
mode_change(){
    old=${1}
    new=${2}

    if [ "${1}" = "${2}" ]
    then
        echo "${2}"
        return 0
    fi

    case "${old}" in
        '[global]')
            global_setting
            hint_setting
            ;;
        '[zone]')
            ;;
    esac

    echo "${2}"
}

# main
read_create () {
    local current="none"
    while read -r line
    do
        # empty or comment
        if [ -z "$(echo -n ${line})" ] || (echo "${line}" | grep -E '^#' 1>/dev/null 2>&1 )
        then
            continue
        # mode change
        elif echo "${line}" | grep -E '^\[' > /dev/null; then
            current=$(mode_change "${current}" "${line}")
        # global
        elif [ "${current}" = '[global]' ]; then
            global_conf "${line}"
        # zone
        elif [ "${current}" = '[zone]' ]; then
            eval "zone_setting ${line}"
        fi
    done < "${conf_file}"

    mode_change "${current}" "none" > /dev/null
}

mkdir -p "${bind_directory}"
clear_data
read_create
