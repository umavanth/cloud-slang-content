#!/bin/bash

inc_and_sleep()
{
  ((WAITING_TIME+=SLEEP_INTERVAL))
  sleep ${SLEEP_INTERVAL}
}

# generate discovery URL for the new CoreOS cluster and update the cloud-config file
DISCOVERY_URL=$(curl -s -X GET "https://discovery.etcd.io/new")
echo "DISCOVERY_URL: $DISCOVERY_URL"
DISCOVERY_URL_ESCAPED=$(echo ${DISCOVERY_URL} | sed 's/\//\\\//g')
sed -i "s/<discovery_url>/${DISCOVERY_URL_ESCAPED}/g" ci-env/cloud-config.yaml
# cat ci-env/cloud-config.yaml

COREOS_MACHINE_NAMES="\
ci-${CIRCLE_BRANCH}-${CIRCLE_BUILD_NUM}-coreos-1 \
ci-${CIRCLE_BRANCH}-${CIRCLE_BUILD_NUM}-coreos-2 \
ci-${CIRCLE_BRANCH}-${CIRCLE_BUILD_NUM}-coreos-3"
for COREOS_MACHINE in ${COREOS_MACHINE_NAMES}
do
  CURL_OUTPUT=$(curl -i -s -X POST https://api.digitalocean.com/v2/droplets \
                -H 'Content-Type: application/json' \
                -H "Authorization: Bearer $DO_API_TOKEN" \
                -d "{
                  \"name\":\"${COREOS_MACHINE}\",
                  \"ssh_keys\":[${DO_DROPLET_SSH_PUBLIC_KEY_ID}],"'
                  "region":"ams3",
                  "size":"512mb",
                  "image":"coreos-stable",
                  "backups":false,
                  "ipv6":false,
                  "private_networking":true,
                  "user_data": "'"$(cat ci-env/cloud-config.yaml | sed 's/"/\\"/g')"'"
                }')

  # echo "CURL_OUTPUT: $CURL_OUTPUT"

  STATUS_CODE=$(echo ${CURL_OUTPUT} | awk '{print $2}')

  if [ "$STATUS_CODE" = "202" ]
  then
    DROPLET_DETAILS=$(echo "$CURL_OUTPUT" | grep "droplet")
    #  echo "DROPLET_DETAILS: $DROPLET_DETAILS"

    # split after `:` and `,` characters and extract the droplet ID
    DROPLET_ID_JUNK_ARRAY=(${DROPLET_DETAILS//:/ })
    DROPLET_ID_JUNK=${DROPLET_ID_JUNK_ARRAY[2]}
    DROPLET_ID_ARRAY=(${DROPLET_ID_JUNK//,/ })
    DROPLET_ID=${DROPLET_ID_ARRAY[0]}

    DROPLET_ID_ACC+="${DROPLET_ID} "

    echo "$COREOS_MACHINE (ID: $DROPLET_ID) droplet creation request accepted"
  else
    echo "Problem occurred: $COREOS_MACHINE droplet creation request - status code: $STATUS_CODE"
  fi
done

# store droplet IDs in a file to be accessible in cleanup script
# echo $DROPLET_ID_ACC
echo ${DROPLET_ID_ACC} > "droplets_${CIRCLE_BUILD_NUM}.txt"

SLEEP_INTERVAL=5 # 5 sec
TIMEOUT=300 # 5 mins

# retrieve IPv4 addresses of droplets
for DROPLET_ID in ${DROPLET_ID_ACC}
do
  DROPLET_STATUS=''
  WAITING_TIME=0
  while [ "$DROPLET_STATUS" != "active" ] && [ "$WAITING_TIME" -lt "$TIMEOUT" ]
  do
    CURL_OUTPUT=$(curl -i -s -L -X GET -H 'Content-Type: application/json' -H "Authorization: Bearer ${DO_API_TOKEN}" \
    "https://api.digitalocean.com/v2/droplets/$DROPLET_ID")
    # echo "CURL_OUTPUT - GET DROPLET BY ID: $CURL_OUTPUT"

    STATUS_CODE=$(echo "$CURL_OUTPUT" | grep "Status" | awk '{print $2}')
    # echo "STATUS_CODE: $STATUS_CODE"

    if [ "$STATUS_CODE" = "200" ]
    then
      echo "Droplet($DROPLET_ID) information retrieved successfully"

      RESPONSE_BODY_JSON=$(echo "$CURL_OUTPUT" | grep "ip_address")
      # echo "RESPONSE_BODY_JSON: ${RESPONSE_BODY_JSON}"

      if [ "${RESPONSE_BODY_JSON}" = "" ]
      then
        inc_and_sleep
      else
        DROPLET_STATUS=$(\
        echo "$RESPONSE_BODY_JSON" | python -c \
'
import json,sys;
obj = json.load(sys.stdin);
print obj["droplet"]["status"];
'\
      )
        echo "Droplet($DROPLET_ID) status: ${DROPLET_STATUS}"

        if [ "$DROPLET_STATUS" = "active" ]
        then
          IP_ADDRESS=$(\
          echo "$RESPONSE_BODY_JSON" | python -c \
'
import json,sys;
obj = json.load(sys.stdin);
ipv4_list = obj["droplet"]["networks"]["v4"];
ip = ""
for ip_obj in ipv4_list:
  if ip_obj["type"] == "public":
    ip = ip_obj["ip_address"];
    break;
print ip;
'\
        )
          echo "Droplet($DROPLET_ID) IPv4 address: $IP_ADDRESS"

          DROPLET_IP_ADDRESS_ACC+="${IP_ADDRESS} "
          # echo "DROPLET_IP_ADDRESS_ACC: $DROPLET_IP_ADDRESS_ACC"
        else
          inc_and_sleep
        fi
      fi
    else
      echo "Problem occurred: retrieving droplet($DROPLET_ID) information - status code: $STATUS_CODE"
    fi
  done
  if [ "$DROPLET_STATUS" != "active" ]
  then
    echo "Droplet($DROPLET_ID) is not active after ${WAITING_TIME}"
  fi
done

# update inputs files to use actual IP addresses
DROPLET_IP_ARRAY=(${DROPLET_IP_ADDRESS_ACC})
sed -i "s/<coreos_host>/${DROPLET_IP_ARRAY[0]}/g" test/io/cloudslang/coreos/test_access_coreos_machine.inputs.yaml
sed -i "s/<coreos_host>/${DROPLET_IP_ARRAY[0]}/g" test/io/cloudslang/coreos/cluster_docker_images_maintenance.inputs.yaml

# create ssh private key
SSH_KEY_PATH=droplets_rsa
echo -e "${DO_DROPLET_SSH_PRIVATE_KEY}" > ${SSH_KEY_PATH}
cat "${SSH_KEY_PATH}"
# ls -l .

# update inputs files to use actual ssh key
sed -i "s/<private_key_file>/${SSH_KEY_PATH}/g" test/io/cloudslang/coreos/test_access_coreos_machine.inputs.yaml
sed -i "s/<private_key_file>/${SSH_KEY_PATH}/g" test/io/cloudslang/coreos/cluster_docker_images_maintenance.inputs.yaml

cat test/io/cloudslang/coreos/test_access_coreos_machine.inputs.yaml
cat test/io/cloudslang/coreos/cluster_docker_images_maintenance.inputs.yaml
