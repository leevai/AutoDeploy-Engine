installPath=#{installPath}
hostIp=#{hostIp}
installType=#{installType}
release=#{release}
oldRelease=#{oldRelease}
databaseType=#{databaseType}
logFile=#{logFile}
installNodeType=#{installNodeType}
workdir=#{workdir}
mysqluser=#{mysqluser}
mysqlpassword=#{mysqlpassword}
mysqlhost=#{mysqlhost}
mysqlhostport=#{mysqlhostport}


. ./script/lib/common.sh
. ./script/lib/common_unroot.sh
. ./script/lib/start_service.sh
. ./script/lib/dir_auth.sh

function __InstallAiCure() {
   aicureBaseDir=${installPath}/aicure/
   if [[ $( __readINI zcloud.cfg aicure enabled )  == 1 ]]; then
        typeset -r nodeType=${2}
        if [[ $( __readINI nodeconfig/current.cfg service mysql )  == 1 && ${installType} = 1  ]]; then
           #初始化mysql资料库
           __initMysqlData "${1}"
        elif [[ $( __readINI nodeconfig/current.cfg service mysql )  == 1 && ${installType} = 2 && ! -f /usr/lib/systemd/system/ai-business.service  ]]; then
          __initMysqlData "${1}"
        elif [[ ${release} == "enterprise" && ${oldRelease} == "standard" && $( __readINI nodeconfig/current.cfg service mysql )  == 1 ]];then
          __initMysqlData "${1}"
        else
         echo "The user chose not to install mysql"
        fi

        # 启动后端服务
        __StartBackend "${1}"

        # 启动前端服务
        __StartFrontend "${1}"
   fi
}

function __initMysqlData(){
  if [[ ${databaseType} != "MogDB" ]];then
    echo "检查是否已安装mysql"
    localIP=${1}
    zcloudCfg=${workdir}/zcloud.cfg
#    if [[ ${installNodeType} == "OneNode" ]]; then
#              mysqlhostIp=$(__readINI ${zcloudCfg} single mysql.service.ip)
#              mysqlhostport=$(__readINI ${zcloudCfg} single mysql.service.port)
#              __mysqlRootPwd=$(__readINI ${zcloudCfg} single mysql.root.paasword)

#    else
#              mysqlhostIp=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
#              mysqlhostport=$(__readINI ${zcloudCfg} multiple mysql.service.port)
#              __mysqlRootPwd=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)

#    fi

    if [[ ${installType} = 1 ]];then
      ${installPath}/soft/mysql/mysql/bin/mysql -uroot -p${mysqlpassword} -h${mysqlhost} -P${mysqlhostport} < dbsqlfile/aicure/init.sql >> ${logFile} 2>&1
    else
      mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      ${mysqlAddr} -uroot -p${mysqlpassword} -h${mysqlhost} -P${mysqlhostport} < dbsqlfile/aicure/init.sql >> ${logFile} 2>&1
    fi

    retCode=$?
    if [[ ${retCode} == 0 ]]; then
        success "初始化 aicure mysql 数据成功"
    else
        error "AiCure MySQL database init failed,please manual import dbsqlfile/aicure/init.sql "
        exit 1
    fi
  fi
}

function __StartFrontend() {

    if [[ ${installNodeType} == "OneNode" ]]; then
      localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
    else
      localIP=$( __readINI zcloud.cfg multiple consul.host )
    fi

    business_server_port=($( __readINI zcloud.cfg aicure "aicure.business.server.port" ))
    echo "Start frontend...localIP = ${localIP}"

    rm -rf ${installPath}/soft/nginx/nginx/html/aicure
    cp -r web/aicure ${installPath}/soft/nginx/nginx/html/
    chmod -R 755 ${installPath}/soft/nginx/nginx/html/aicure

    nginx_conf_path=${installPath}/soft/nginx/nginx/conf/nginx.conf
    __ReplaceTextSed "${nginx_conf_path}" "ai-business-ip" "${localIP}"
    __ReplaceTextSed "${nginx_conf_path}" "ai-business-port" "${business_server_port}"
    __restartNginx
    success "Start frontend success"
}

function __StartBackend() {
    __CreateDir "${installPath}/aicure/"

    zcloudCfg=${workdir}/zcloud.cfg
    if [[ ${installNodeType} == "OneNode" ]]; then
              localIP=$(__readINI ${zcloudCfg} single mysql.service.ip)
    else
              localIP=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
    fi

    version=`cat ${workdir}/version.txt`
    versionPath=${logPath}/${version}
    if [[ ! -d ${versionPath} ]];then
      mkdir -p ${versionPath}
    fi

    for app in `ls jar/aicure`
    do
        if [[ ${app} == "zcloud-ai-adapter" ]];then
          app1="zcloud_ai_adapter"
        fi
        if [[ ${app} == "ai-business" ]];then
          app1="ai_business"
        fi
        echo ""
        echo "initialize Application [${app}] ..."
        echo "${app}" >> ${installPath}/serviceTemp
        echo "[${app}]">>${versionPath}/version.cfg
        if [[ ! -e ${installPath}/aicure/${app} ]];then
          nowVersion=$(ls jar/aicure/${app}/${app}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
          echo "type=全新安装">>${versionPath}/version.cfg
          echo "newVersion=${nowVersion}">>${versionPath}/version.cfg
          cp -r jar/aicure/${app}/ ${installPath}/aicure/
          __GenAppProper_${app1} "${app}" "${localIP}"
          success "Initialize Application [${app}] success"

          cp conf/logback/logback-default.xml ${aicureBaseDir}/${app}/config/
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}/aicure/${app}'/"/>#g' ${aicureBaseDir}/${app}/config/logback-default.xml
          mv ${aicureBaseDir}/${app}/config/logback-default.xml ${aicureBaseDir}/${app}/config/logback.xml
         port=$(__CheckPort ${app})
         if [[ ${port} -gt 0 ]];then
           error "${port}端口已被占用，${app}安装失败,安装中断"
           exit 1
         fi
          __StartService "aicure/${app}" "${app}"
        else
          nowVersion=$(ls jar/aicure/${app}/${app}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
          oldVersion=$(ls ${installPath}/aicure/${app}/${app}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
          if [[ ${nowVersion} != ${oldVersion} ]]; then
            echo "type=升级替换">>${versionPath}/version.cfg
            echo "newVersion=${nowVersion}">>${versionPath}/version.cfg
            echo "oldVersion=${oldVersion}">>${versionPath}/version.cfg
            jarName=$(ls ${installPath}/aicure/${app}/${app}*.jar | awk -F'/' '{print $NF}')
            influxToken=`grep "spring.influx.token" ${installPath}/aicure/${app}/config/application.properties |sed 's/=/###/' |awk -F'###' '{print $2}'`
            __GenAppProper_${app1} "${app}" "${localIP}"
            if [[ $(ps -ef | grep ${app}/${app} | grep -v grep| wc -l) -gt 0 ]]; then
              echo "原安装包运行状态=active">>${versionPath}/version.cfg
              ps -ef | grep ${app}/${app} | grep -v grep | awk '{print $2}' | xargs kill -9
              echo "关闭${app}成功"
              sleep 2s
            else
              echo "原安装包运行状态=inactive">>${versionPath}/version.cfg
            fi
            port=$(__CheckPort ${app})
            if [[ ${port} -gt 0 ]];then
              error "${port}端口已被占用，${app}安装失败,安装中断"
              exit 1
            fi
            mv ${installPath}/aicure/${app}/${jarName} ${installPath}/aicure/${app}/${jarName}.bak
            echo "复制${app}到安装目录"
            cp -r jar/aicure/${app}/ ${installPath}/aicure/
            __GenAppProper_${app1} "${app}" "${localIP}"
            success " [${app}]安装完成"

            cp conf/logback/logback-default.xml ${aicureBaseDir}/${app}/config/
            sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}/aicure/${app}'/"/>#g' ${aicureBaseDir}/${app}/config/logback-default.xml
            mv ${aicureBaseDir}/${app}/config/logback-default.xml ${aicureBaseDir}/${app}/config/logback.xml
            __StartService "aicure/${app}" "${app}"
            echo "重启${app}成功"
          else
            echo "type=无需替换">>${versionPath}/version.cfg
            echo "newVersion=${nowVersion}">>${versionPath}/version.cfg
            echo "oldVersion=${oldVersion}">>${versionPath}/version.cfg
            if [[ $(ps -ef | grep ${app}/${app} | grep -v grep | wc -l) == 0 ]]; then
              echo "原安装包运行状态=inactive">>${versionPath}/version.cfg
              echo "原服务${app}已停止，需要重新启动成功"
              port=$(__CheckPort ${app})
              if [[ ${port} -gt 0 ]];then
                error "${port}端口已被占用，${app}安装失败,安装中断"
                exit 1
              fi
              __StartService "aicure/${app}" "${app}"
              echo "重启${app}成功"
            else
              echo "原安装包运行状态=active">>${versionPath}/version.cfg
              echo "${app}版本没有变化，且处于正常的运行状态，无需处理"
            fi
          fi
        fi
        \cp -f ${workdir}/script/start.sh ${installPath}/aicure/${app}
        \cp -f ${workdir}/script/stop.sh ${installPath}/aicure/${app}
    done
}

function __GenAppProper_ai_business(){
    typeset -r appName=${1}
    if [[ ${databaseType} = "MogDB" ]];then

      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} single mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} single mogdb.password)
        localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
        prometheusIp=$( __readINI ${zcloudCfg} single "prometheus.service.ip" )
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mogdb.password)
        localIP=$( __readINI zcloud.cfg multiple web.ip )
        prometheusIp=$( __readINI ${zcloudCfg} multiple "prometheus.service.ip" )
      fi
      dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_password}`
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.url" "spring.datasource.url=jdbc:opengauss://${server_ip}:${server_port}/zcloud?currentSchema=ai_cure"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "database.address" "database.address=${server_ip}:${server_port}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.username" "spring.datasource.username=${dbaas_username}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.password" "spring.datasource.password=${dbaas_paasword_encode}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driverClassName" "spring.datasource.driverClassName=org.opengauss.Driver"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driver-class-name" "spring.datasource.driver-class-name=org.opengauss.Driver"


    else

      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mysql" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} single mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} single mysql.root.paasword)
        localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
        prometheusIp=$( __readINI ${zcloudCfg} single "prometheus.service.ip" )
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mysql" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
        localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
        prometheusIp=$( __readINI ${zcloudCfg} single "prometheus.service.ip" )
      fi
      dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_password}`
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "database.address" "database.address=${server_ip}:${server_port}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.url" "spring.datasource.url=spring.datasource.url=jdbc:mysql://${server_ip}:${server_port}/dbaas?characterEncoding=UTF-8&autoReconnect=true&allowMultiQueries=true&serverTimezone=GMT%2B8"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.username" "spring.datasource.username=${dbaas_username}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.password" "spring.datasource.password=${dbaas_paasword_encode}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driverClassName" "spring.datasource.driverClassName=com.mysql.jdbc.Driver"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driver-class-name" "spring.datasource.driver-class-name=com.mysql.jdbc.Driver"
    fi
    # 替换influx的配置
    influx_server_ip=($( __readINI zcloud.cfg aicure "aicure.influx.ip" ))
    influx_server_port=($( __readINI zcloud.cfg aicure "aicure.influx.port" ))
    influx_org=($( __readINI zcloud.cfg aicure "aicure.influx.org" ))
    influx_bucket=($( __readINI zcloud.cfg aicure "aicure.influx.bucket" ))
    influx_token=($( __readINI zcloud.cfg aicure "aicure.influx.token" ))

    if [[ ${influxToken} == "" ]];then

      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.influx.token" "spring.influx.token=${influx_token}"
    else
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.influx.token" "spring.influx.token=${influxToken}"
    fi
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.influx.url" "spring.influx.url=http://${influx_server_ip}:${influx_server_port}"
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.influx.org" "spring.influx.org=${influx_org}"
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.influx.bucket" "spring.influx.bucket=${influx_bucket}"

    ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
    # 替换登陆地址
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "login.url" "login.url=http://${localIP}:${ui_url_port}/enmoLogin"

    # 替换服务端口
    business_server_port=($( __readINI zcloud.cfg aicure "aicure.business.server.port" ))
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "server.port" "server.port=${business_server_port}"

     # 替换 prometheus ip
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "prometheus.ip" "prometheus.ip=${prometheusIp}"
}

function __GenAppProper_zcloud_ai_adapter(){
    typeset -r appName=${1}
    if [[ ${databaseType} = "MogDB" ]];then
      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} single mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} single mogdb.password)
        localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
        prometheusIp=$( __readINI ${zcloudCfg} single "prometheus.service.ip" )
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mogdb.password)
        localIP=$( __readINI zcloud.cfg multiple web.ip )
        prometheusIp=$( __readINI ${zcloudCfg} multiple "prometheus.service.ip" )
      fi
      dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_password}`

      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.url" "spring.datasource.url=jdbc:opengauss://${server_ip}:${server_port}/zcloud?currentSchema=dbaas"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.username" "spring.datasource.username=${dbaas_username}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.password" "spring.datasource.password=${dbaas_paasword_encode}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driverClassName" "spring.datasource.driverClassName=org.opengauss.Driver"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driver-class-name" "spring.datasource.driver-class-name=org.opengauss.Driver"
    else

      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mysql" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} single mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} single mysql.root.paasword)
        localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
        prometheusIp=$( __readINI ${zcloudCfg} single "prometheus.service.ip" )
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mysql" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
        localIP=$( __readINI zcloud.cfg multiple web.ip )
        prometheusIp=$( __readINI ${zcloudCfg} multiple "prometheus.service.ip" )
      fi
      dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_password}`

      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.url" "spring.datasource.url=jdbc:mysql://${server_ip}:${server_port}/dbaas?characterEncoding=UTF-8&autoReconnect=true&allowMultiQueries=true&serverTimezone=GMT%2B8"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.username" "spring.datasource.username=${dbaas_username}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.password" "spring.datasource.password=${dbaas_paasword_encode}"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driverClassName" "spring.datasource.driverClassName=com.mysql.jdbc.Driver"
      __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "spring.datasource.driver-class-name" "spring.datasource.driver-class-name=com.mysql.jdbc.Driver"
    fi
    # 替换服务端口
    adapter_server_port=($( __readINI zcloud.cfg aicure "aicure.adapter.server.port" ))
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "server.port" "server.port=${adapter_server_port}"

    # 替换business 服务端口
    business_server_port=($( __readINI zcloud.cfg aicure "aicure.business.server.port" ))
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "ai.cure.business.servers\[0\].port" "ai.cure.business.servers[0].port=${business_server_port}"
    __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "ai.cure.business.servers\[0\].ip" "ai.cure.business.servers[0].ip=${localIP}"

    # 替换 prometheus ip
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "prometheus.ip" "prometheus.ip=${prometheusIp}"

     # 替换 网关地址
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "gateway.url" "gateway.url=http://${localIP}:${ui_url_port}"

      # 替换infrastructure 地址
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "customer.url" "customer.url=http://${localIP}:8023/dbaasInfrastructure"
     # 替换monitor 地址
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "monitor.url" "monitor.url=http://${localIP}:8091/monitorApplication"
      # 替换db-manage 地址
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "dbmanage.url" "dbmanage.url=http://${localIP}:8190/dbaasDbManage"
      # 替换monitor 地址
     __ReplaceText "${aicureBaseDir}/${appName}/config/application.properties" "dbaasApiGateWay.url" "dbaasApiGateWay.url=http://${localIP}:8088/dbaasApiGateWay"

}

function __restartNginx(){
    ${installPath}/soft/nginx/nginx/sbin/nginx -s stop
    ${installPath}/soft/nginx/nginx/sbin/nginx  -c  ${installPath}/soft/nginx/nginx/conf/nginx.conf
}

__InstallAiCure "${hostIp}" ${installNodeType}