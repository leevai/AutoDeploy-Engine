installPath=#{installPath}
workdir=#{workdir}
ui_url_port=#{ui_url_port}
logPath=#{logPath}
hostIp=#{hostIp}
theme=#{theme}
realHostIp=#{hostIp}
installType=#{installType}
installNodeType=#{installNodeType}
workflowIp=#{workflowIp}

. ./script/lib/common.sh
. ./script/lib/dir_auth.sh

function __CheckNginx {
    set +e
    fileInfo=`ls ${installPath}/soft/nginx/nginx/sbin/nginx 2>&1`
    if [[ $fileInfo != *"cannot access"* ]]; then
        info "${fileInfo}"
    fi
    set -e
    if [[ ! -e ${installPath}/soft/nginx/nginx/sbin/nginx ]]
    then
      info "此步骤大概需要执行3m,请等待"
      __InstallNginx
    else
      info "nginx已安装，无需重新安装"
    fi
    \cp -f ${workdir}/script/other/start.sh ${installPath}/soft/nginx
    \cp -f ${workdir}/script/other/stop.sh ${installPath}/soft/nginx
    __GetNginxVersion

    if [[ "${nginx_version_part1}" -ge "1" ]]; then
        if [[ "${nginx_version_part2}"  -ge "10" ]]; then
            info "Nginx Check Sucessed , Version Must gt 1.10"
        else
            info "Nginx Check Failed , Version Must gt 1.10, please Uninstall and reinstall 1.10+"
            exit 1
        fi
    fi
    __InstallWeb
}

function __InstallNginx {
    info "This Machine Not Install Nginx, Will Install Nginx "
    port=$(__CheckPort nginx)
    if [[ ${port} -gt 0 ]];then
      error "${port}端口已被占用，nginx安装失败,安装中断"
      exit 1
    fi
    cd ${workdir}
    __CreateDir "${installPath}/soft/"
    tar -zxf soft/nginx/nginx.tar.gz -C "${installPath}/soft/"

    chown -R zcloud:zcloud ${installPath}/soft/nginx
    retCode=$?
    if [[ ${retCode} == 0 ]]; then
        info  "Install Nginx Sucessed"
    else
        error "Install Nginx Failed"
        exit 1
    fi
    echo "" > ${installPath}/soft/nginx/nginx/logs/error.log
}


function __GetNginxVersion {
    ${installPath}/soft/nginx/nginx/sbin/nginx -v 2>${logPath}/nginxversion.txt
    nginxVerion=`cat ${logPath}/nginxversion.txt |grep nginx`

    if [[ "${nginxVerion}" =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
    then
        nginx_version=${BASH_REMATCH[1]}
        nginx_version_part1=${BASH_REMATCH[2]}
        nginx_version_part2=${BASH_REMATCH[3]}

        info "Nginx Version: $nginx_version"
    else
        error "Failed to parse Nginx Version."
        exit 1
    fi
}

function __InstallWeb {
    nginxIp=${hostIp}
    if [[ ${theme} == "zData" ]];then
      nginxIp=${realHostIp}
    fi
    info "web安装当前ip ${nginxIp} "
    nginx_path=${installPath}/soft/nginx/nginx/sbin/nginx
    nginx_conf_path=${installPath}/soft/nginx/nginx/conf/nginx.conf
    cd ${workdir}
    if [[ ${installType} = 4 ]];then
      bakTimePath=($( __ReadValue ${logPath}/evn.cfg bakTimePath))
      rm -rf ${installPath}/soft/nginx/nginx/html/
      mkdir -p ${installPath}/soft/nginx/nginx/html/
      cp -r ${workdir}/web/* ${installPath}/soft/nginx/nginx/html/

      if [[ `grep "gtjadbass" ${nginx_conf_path} |wc -l` -gt 0 ]];then
        info "国泰君安前端升级中... "
        cp conf/custom_nginx_conf/nginx_gtja.conf ${nginx_conf_path}
        __ReplaceTextSed " ${nginx_conf_path}" "#hostIp#" "${hostIp}"
        __ReplaceTextSed " ${nginx_conf_path}" "#zcloudHomePath#" `cd ~ && pwd`
        info "国泰君安前端升级完成... "
      else
        lineNum=`sed -n "/client_header_timeout/=" ${nginx_conf_path}`
        if [[ `grep "client_header_buffer_size" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "    client_header_buffer_size   2m;">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        lineNum=`sed -n "/location \/theme\/img/=" ${nginx_conf_path}`
        if [[ `grep "location ~ /lcdp" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ~ /lcdp {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://dbaas-zuul/dbaasApiGateWay\$request_uri;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location ~ /workflow" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ~ /workflow {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://dbaas-zuul/dbaasApiGateWay\$request_uri;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location ~ /magicCube" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ~ /magicCube {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://dbaas-zuul/dbaasApiGateWay\$request_uri;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location /pysrc" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location /pysrc {
              alias /paasdata/python/2.7.5;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location ^~ /aicure/whitelist" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "location ^~ /aicure/whitelist {
                      alias /home/zcloud/dbaas/soft-install/soft/nginx/nginx/html/aicure;
                      try_files $uri $uri/ /index.html;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location ~ /api/" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ~ /api/ {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://dbaas-zuul/dbaasApiGateWay\$request_uri;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi

        if [[ `grep "location ~ /openAPI" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ~ /openAPI {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://dbaas-zuul/dbaasApiGateWay\$request_uri;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi


        lineNum=`sed -n "/location ~ \/monitorApplication/=" ${nginx_conf_path}`
        if [[ `grep "location ~ /ekb/" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ~ /ekb/ {
                 proxy_redirect off;
                 proxy_set_header Host \$host;
                 proxy_set_header X-Real-IP \$remote_addr;
                 proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                 proxy_pass http://dbaas-zuul/dbaasApiGateWay/dbaas-knowledge\$request_uri;
            }

            location ^~ /knowledge {
                 alias ${installPath}/soft/nginx/nginx/html/expert-knwl-base;
                 try_files \$uri \$uri/ /index.html;
            }
            location = /ekb/attachments/upload {
                  proxy_redirect off;
                  proxy_set_header Host \$host;
                  proxy_set_header X-Real-IP \$remote_addr;
                  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  proxy_pass http://${nginxIp}:8011\$request_uri;

            }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location /docCenter" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location /docCenter {
              alias ${installPath}/soft/nginx/nginx/html/docCenter;
              try_files \$uri \$uri/  /index.html;
          }
          location = /dbaasDocCenter/attachments/upload {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://${nginxIp}:9181\$request_uri;
          }

          location = /dbaasDocCenter/docInfo/import {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://${nginxIp}:9181\$request_uri;
          }
          location ^~ /dbaasDocCenter/attachments/download {
              proxy_redirect off;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_pass http://${nginxIp}:9181\$request_uri;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
        if [[ `grep "location ^~ /webMonitorScreen" ${nginx_conf_path}|wc -l` -eq 0 ]];then
          echo "        location ^~ /webMonitorScreen {
              alias ${installPath}/soft/nginx/nginx/html/webMonitorScreen;
              try_files \$uri \$uri/ /index.html;
          }">temp
          sed -i "$[${lineNum}-1]r temp" ${nginx_conf_path}
          rm -f temp
        fi
      fi
    else
      if [[ ${installType} = 2 ]];then
        if [[ -d /usr/share/nginx/static/image/ && `ls /usr/share/nginx/static/image/|wc -l` -gt 0 ]];then
          __CreateDir "${installPath}/soft/nginx/nginx/static/image/"
          cp -ru /usr/share/nginx/static/image/* ${installPath}/soft/nginx/nginx/static/image/
        fi
        lineNum=`sed -n "/location \/download\//=" /etc/nginx/nginx.conf`
        nginxPackagesPath=`sed -n $[${lineNum}+1]p /etc/nginx/nginx.conf|awk -F' ' '{print $NF}' |awk -F';' '{print $1}'`
        if [[ -d ${nginxPackagesPath}/download/sys/ && `ls ${nginxPackagesPath}/download/sys/|wc -l` -gt 0 ]];then
          cp -ru ${nginxPackagesPath}/download/sys/* ${installPath}/packages/download/sys
        fi
      fi
      if [[ ${theme} == "zData" ]];then
        cp web/nginx_zdata.conf ${nginx_conf_path}
      else
        cp web/nginx.conf ${nginx_conf_path}
      fi

      sed -i "s|#installPath#|${installPath}|g" ${nginx_conf_path}
      cp lib/404.html  ${installPath}/soft/nginx/nginx/html/
      cp lib/error.html  ${installPath}/soft/nginx/nginx/html/
      cp -r ${workdir}/web/* ${installPath}/soft/nginx/nginx/html/
      chmod -R 755 ${nginx_conf_path}
      packages_path=${installPath}/packages
      sed -i '23s/$/\n    server_tokens off;/g'  ${nginx_conf_path}
      sed -i '/autoindex on;/a     \             error_page 404 /404.html;\'  ${nginx_conf_path}
      sed -i '\/location \/reborn {/i\        location /404.html {\n            root   /tmpdir;\n        }'  ${nginx_conf_path}
      __ReplaceTextSed " ${nginx_conf_path}" "/var/log/nginx/error.log" "${installPath}/soft/nginx/nginx/logs/error.log"
      __ReplaceTextSed " ${nginx_conf_path}" "/var/run/nginx.pid;" "${installPath}/soft/nginx/nginx/nginx.pid;"
      __ReplaceTextSed " ${nginx_conf_path}" "/etc/nginx/mime.types;" "${installPath}/soft/nginx/nginx/conf/mime.types;"
      __ReplaceTextSed " ${nginx_conf_path}" "/var/log/nginx/access.log" "${installPath}/soft/nginx/nginx/logs/access.log"
      __ReplaceTextSed " ${nginx_conf_path}" "/usr/share/nginx/static/image/" "${installPath}/soft/nginx/nginx/static/image/"
      __ReplaceTextSed " ${nginx_conf_path}" "user  nginx;" " "
      __ReplaceTextSed " ${nginx_conf_path}" "include /etc/nginx.*" " "
      __ReplaceTextSed " ${nginx_conf_path}" "root   /tmpdir;" "root   ${installPath}/lib/;"
      __ReplaceTextSed " ${nginx_conf_path}" "/usr/share/nginx/html/" "${installPath}/soft/nginx/nginx/html/"
      __ReplaceTextSed " ${nginx_conf_path}" "root /data/packages/;" "root ${packages_path};"
      if [[ ${theme} == "zData" ]];then
        __ReplaceTextSed " ${nginx_conf_path}" "listen 80;" "listen ${ui_url_port} ssl;"
      else
        __ReplaceTextSed " ${nginx_conf_path}" "listen 80;" "listen ${ui_url_port};"
      fi

      __ReplaceTextSed " ${nginx_conf_path}" "hfbank-dbaas-apigateway" "${nginxIp}"
      __ReplaceTextSed " ${nginx_conf_path}" "zcloud-dbaas-apigateway" "${nginxIp}"
      __ReplaceTextSed " ${nginx_conf_path}" "zcloud-dbaas-monitor" "${nginxIp}"
      __ReplaceTextSed " ${nginx_conf_path}" "proxy_read_timeout 300s;" "proxy_read_timeout 3600s;"
      __ReplaceTextSed " ${nginx_conf_path}" "proxy_send_timeout 300s;" "proxy_send_timeout 3600s;"
      __ReplaceTextSed " ${nginx_conf_path}" "#hostIp#" "${nginxIp}"
    fi


    __LowCodeWorkFlowConfig

    if [[ `ps -ef|grep soft/nginx|grep master|grep -v proxy | awk '{print $2}'|wc -l ` -gt 0 ]]; then
          ps -ef |grep soft/nginx|grep master|grep -v proxy | awk '{print $2}' | xargs kill -15
          sleep 5s
    fi

    if [[ `ps -ef|grep "nginx: worker process"|grep " 1 "|wc -l ` -gt 0 ]]; then
          ps -ef |grep "nginx: worker process"|grep " 1 "| awk '{print $2}' | xargs kill -9
          sleep 5s
    fi
    #启动nginx
    ${nginx_path} -p ${installPath}/soft/nginx/nginx -c ${nginx_conf_path}
    retCode=$?
    # retCode=0
    if [[ ${retCode} == 0 ]]; then
        info  "Start Nginx Sucessed"
    else
        error "Start Nginx Failed"
        exit 1
    fi

}

function __LowCodeWorkFlowConfig {
  if [[ ${installNodeType} == "OneNode" ]]; then
    workflowIp=${hostIp}
  else
    workflowIp=${workflowIp}
  fi

  if [[ `grep "upstream lowcodeworkflow_service" ${nginx_conf_path}|wc -l` == 0 ]];then
    line=`grep -n } ${nginx_conf_path}|tail -1|awk -F':' '{print $1}'`
    if [[ ${realHostIp} == "127.0.0.1" ]];then
      nginxIp=""
    else
      nginxIp=${realHostIp}
    fi
    echo "    upstream lowcodeworkflow_service {
    }

    server {
            listen 18080;
            valid_referers blocked server_names 127.0.0.1 localhost ${nginxIp};
            set \$invalid_referer_flag 0;
            if (\$request_uri ~* \.(gif|jpg|png|bmp|js|css)$){
               set \$invalid_referer_flag \$invalid_referer;
            }
            if (\$invalid_referer_flag) {
                return 403;
            }
            charset utf-8;
            location /{
                    proxy_pass  http://lowcodeworkflow_service;
                    proxy_redirect     off;
                    proxy_set_header   Host             \$host;
                    proxy_set_header   X-Real-IP        \$remote_addr;
                    proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
            }
    }">temp
    sed -i "$[${line}-1]r temp" ${nginx_conf_path}
    if [[ `ps -ef|grep "manage.py runserver 0.0.0.0:18080" |grep -v grep |wc -l` -gt 0 ]];then
      ps -ef|grep "manage.py runserver 0.0.0.0:18080" |grep -v grep | awk '{print $2}' | xargs kill -9
      sleep 2
    fi
  fi

  if [[ ${installNodeType} == "OneNode" ]]; then
    lowcodeIp=${hostIp}
  else
    lowcodeIp=${workflowIp}
  fi


  if [[ `grep "upstream atomic_ability_service" ${nginx_conf_path}|wc -l` == 0 ]];then
    line=`grep -n } ${nginx_conf_path}|tail -1|awk -F':' '{print $1}'`

    if [[ ${realHostIp} == "127.0.0.1" ]];then
      nginxIp=""
    else
      nginxIp=${realHostIp}
    fi
    echo "    upstream atomic_ability_service {
            server ${lowcodeIp}:8916;
    }

    server {
            listen 8914;
            valid_referers blocked server_names 127.0.0.1 localhost ${nginxIp};
            set \$invalid_referer_flag 0;
            if (\$request_uri ~* \.(gif|jpg|png|bmp|js|css)$){
               set \$invalid_referer_flag \$invalid_referer;
            }
            if (\$invalid_referer_flag) {
                return 403;
            }
            charset utf-8;
            location /{
                    proxy_pass  http://atomic_ability_service;
                    proxy_redirect     off;
                    proxy_set_header   Host             \$host;
                    proxy_set_header   X-Real-IP        \$remote_addr;
                    proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
            }
    }">temp
    sed -i "$[${line}-1]r temp" ${nginx_conf_path}
    if [[ `ps -ef|grep "dbaas-lowcode-atomic-ability/dbaas-lowcode-atomic-ability" |grep -v grep |wc -l` -gt 0 ]];then
      ps -ef|grep "dbaas-lowcode-atomic-ability/dbaas-lowcode-atomic-ability" |grep -v grep | awk '{print $2}' | xargs kill -9
      sleep 2
    fi
  fi


  upstreamLine=`grep -n "upstream lowcodeworkflow_service" ${nginx_conf_path} |awk -F':' '{print $1}'`
  offset=`sed -n "${upstreamLine},\$"p ${nginx_conf_path}|grep -n } |head -1|awk -F':' '{print $1}'`
  upstreamEndLine=$[${upstreamLine}+${offset}-1]
  if [[ $[${upstreamEndLine}-1] -ge $[${upstreamLine}+1] ]];then
    sed -i "$[${upstreamLine}+1],$[${upstreamEndLine}-1]d" ${nginx_conf_path}
  fi


  coreNum=`cat /proc/cpuinfo | grep 'processor'| wc -l`
  processNum=$[${coreNum}/8]
  if [[ ${processNum} == 0 ]];then
    processNum=1
  fi
  echo "">temp
  for((i=1;i<=${processNum};i++))
  do
    echo "              server ${workflowIp}:$[18080+i];">>temp
  done
  sed -i "$[${upstreamLine}]r temp" ${nginx_conf_path}
  rm -f temp
}

__CheckNginx