#!/bin/bash
# ------------------------------------------------------------------------------
# registry_list.sh
#
# if you run a local registry the default interface is primitive
# here's an example script that will 
# list all available packages & versions
# given a FQDN or IP and port
# where you are running your registry
#
# assumed here you are running a simple HTTP config
# ------------------------------------------------------------------------------
function fail
{
   echo "ERROR: $1" >&2
   exit 1
}
# ------------------------------------------------------------------------------
function get_catalog_listing
{
  local RX_HOST_SRC="${1}"
  local RX_PORT_SRC="${2}"

  local RX_URL_CATALOG_FETCH="http://${RX_HOST_SRC}:${RX_PORT_SRC}/v2/_catalog"

  if curl -s --head  --request GET ${RX_URL_CATALOG_FETCH} | grep "404 Not Found" > /dev/null
  then
    fail "404 NOT FOUND returned for url: ${RX_URL_CATALOG_FETCH}"
  fi

  mapfile -t RX_LIST_PACKAGES < <( curl -sS -X GET ${RX_URL_CATALOG_FETCH} | jq '.repositories|.[]' | sed -e 's/\"//g' )

  printf "Registry catalog ${RX_HOST_SRC}:${RX_PORT_SRC} contents:\n"

  for RX_CURR_PKG in "${RX_LIST_PACKAGES[@]}"; do
    local RX_URL_VERSIONS_FETCH="http://${RX_HOST_SRC}:${RX_PORT_SRC}/v2/${RX_CURR_PKG}/tags/list"
    mapfile -t RX_PKG_VERSIONS < <( curl -sS -X GET ${RX_URL_VERSIONS_FETCH} | jq '.tags|.[]' | sed -e 's/\"//g' )
    local RX_CURR_PKG_FIXED_NAME="${RX_CURR_PKG}                                                                     "
    printf " ${RX_CURR_PKG_FIXED_NAME:0:35}       [ ${RX_PKG_VERSIONS[*]} ]\n"
  done

}
# ------------------------------------------------------------------------------
function display_usage_message
{
  echo
  echo "Usage: registry_list.sh <FQDN> <port>"
  echo
}
# ------------------------------------------------------------------------------
# main() 

if [ "$#" -lt 2 ]; then
  display_usage_message
else
  get_catalog_listing "${1}" "${2}"
fi

# fini
#
# =============================================================================================
