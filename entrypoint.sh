#!/usr/bin/env bash

DNS_SERVER_IP="127.0.0.11"

logger() {
  echo `date +"%Y-%m-%d %H:%M:%S"` $*
}

get_dns_server() {
  dns_file="/etc/resolv.conf"
  if [ ! -f "${dns_file}" ]; then
    logger "No ${dns_file}"
    return 0
  fi
  dns_server_ip=(`grep "nameserver" ${dns_file} | head -1 | awk '{print $2}'`)
  if [ $? -eq 0 ] && [ ! -z "${dns_server_ip}" ]; then
    DNS_SERVER_IP=${dns_server_ip}
  fi
}

if [ -z "${SHADOWS}" ]; then
  logger "Empty 'SHADOWS'"
else
  logger "SHADOWS: ${SHADOWS}"

  get_dns_server
  logger "sed -i 's/resolver 127.0.0.11/resolver ${DNS_SERVER_IP}/' /usr/local/openresty/nginx/conf/nginx.conf"
  sed -i "s/resolver 127.0.0.11/resolver ${DNS_SERVER_IP}/" /usr/local/openresty/nginx/conf/nginx.conf
  if [ $? -ne 0 ]; then
      logger "Failed!"
    else
      logger "Succeed!"
    fi

  mirrors=""
  shadows=(`echo ${SHADOWS} | tr ',' ' '`)
  traffic=(`echo ${TRAFFIC} | tr ',' ' '`)
  enableLogPayload=(`echo ${ENABLE_LOG_PAYLOAD} | tr ',' ' '`)
  bizlogFptiUrl=${BIZLOG_FPTI_URL}
  logger "shadows(${#shadows[@]}): ${shadows[@]}"
  count=1
  for s in ${shadows[@]}; do
    mirrors="${mirrors}mirror \/mirror${count};"
    logger "${count}: ${s}"
    logger "sed -i 's/upstream mirror${count}_backend { server localhost:9099/upstream mirror${count}_backend { server ${s}; keepalive 64/' /usr/local/openresty/nginx/conf/nginx.conf"
    sed -i "s/upstream mirror${count}_backend { server localhost:9099/upstream mirror${count}_backend { server ${s}; keepalive 64/" /usr/local/openresty/nginx/conf/nginx.conf
    if [ $? -ne 0 ]; then
      logger "Failed!"
    else
      logger "Succeed!"
    fi

    content="local is_mirror${count} = (random_number <= ${traffic[count-1]}) and true or false
if is_mirror${count} then
  local res${count} = ngx.location.capture(\"/backend${count}\", {
    method = ngx.HTTP_POST,
  })
  if res${count} and ${enableLogPayload[count-1]} then
            local model_resp_body = cjson.encode(res${count}.body)
            local biz_url = \"${bizlogFptiUrl}\"
            local headers = {
                [\"Content-Type\"] = \"application/json\",
                [\"accept\"] = \"*/*\",
                [\"correlation_id\"] = correlation_id,
            }
            local json_1 = \"{${shadow_info_str},\\\"event_name\\\":\\\"${EVENT_NAME}\\\",\\\"metadata\\\":[\"
            local json_2 = \"],\\\"variable\\\":[\"
            local json_3 = \"]}\"
            local biz_req_body = json_1 ..request_body .. json_2 .. model_resp_body .. json_3
            local res, err = httpc:request_uri(biz_url, {
                method = \"POST\",
                body = biz_req_body,
                headers = headers,
                ssl_verify = false,
                timeout = 1000,
            })
        end
end"
    echo -e "$content" >> /app/shadow_invoke.lua
    count=$(( ${count} + 1 ))
  done

  logger "sed -i 's/mirror \/mirror1;.*$/${mirrors}/' /usr/local/openresty/nginx/conf/nginx.conf"
  sed -i "s/mirror \/mirror1;.*$/${mirrors}/" /usr/local/openresty/nginx/conf/nginx.conf
  if [ $? -ne 0 ]; then
      logger "Failed!"
    else
      logger "Succeed!"
    fi
  logger "cat /usr/local/openresty/nginx/conf/nginx.conf:"
  cat /usr/local/openresty/nginx/conf/nginx.conf
  echo -e "\n"
fi

/usr/local/openresty/nginx/sbin/nginx -g "daemon off;"
