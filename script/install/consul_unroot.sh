#!/bin/bash
#安装consul
installNodeType=$( __readINI zcloud.cfg installtype install.node.type )
nodeNum=$( __ReadValue nodeconfig/installparam.txt nodeNum)

function __InstallConsul() {
  #清除已安装的consul
  typeset -r localconsulIP=${hostIp}
  __CreateDir "${installPath}/soft/consul/"
  __CreateDir "${installPath}/soft/consul/log"
  if [[ -f ${bakTimePath}/consultoken.txt ]]; then
        info "备份目录存在consul acl配置"
        cp ${bakTimePath}/consultoken.txt ${configPath}/
  fi

  #如果已安装consul ,不再安装
  if [[ $(ps -ef|grep consul/|grep -v grep|wc -l) -gt 0 ]]; then
    tar -xf ${workdir}/soft/consul/consul.singlenode.tar.gz -C "${workdir}/soft/consul/"
    cp ${workdir}/soft/consul/consul/globalconfig.txt ${installPath}/soft/consul/consul/globalconfig.txt
    cp ${workdir}/soft/consul/consul/consul_kv.json ${installPath}/soft/consul/consul/consul_kv.json
    info "consul 已安装，无需重复安装"
    resetConsul=0
    #判断是否有acl
    if [[ ! -f ${configPath}/consultoken.txt ]]; then
          info "旧版consul未配置acl重新配置"
          #添加consul acl
          echo 'acl = {
            enabled = true
            default_policy = "deny"
            enable_token_persistence = true
          }' > ${installPath}/soft/consul/consul/config/agent.hcl

          if [[ `ps -ef | grep /consul/consul | grep -v grep|wc -l` -gt 0 ]];then
            #重启consul
            ps -ef | grep /consul/consul | grep -v grep | awk '{print $2}' | xargs kill -9
            sleep 5
          fi
          resetConsul=0
          nohup ${installPath}/soft/consul/consul/consul agent -server -data-dir=${installPath}/soft/consul/consul/data/ -node=agent-one -config-dir=${installPath}/soft/consul/consul/config/ -bind=127.0.0.1 -bootstrap-expect=1 -client=0.0.0.0 -ui -log-file=${installPath}/soft/consul/consul/logs/ -log-rotate-bytes=10485760 -log-rotate-max-files=10 &>>${installPath}/soft/consul/log/info.log &
          sleep 20s
          ackValue=`${installPath}/soft/consul/consul/consul acl bootstrap`
          if [[ ${ackValue} != "" ]];then
            #生成token并设置环境变量-保证consul cli正常使用
            echo "${ackValue}" > ${configPath}/consultoken.txt
          fi

          #设置环境变量-保证consul cli正常使用
          consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
          export CONSUL_HTTP_TOKEN=${consulToken}
          CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
          info "consul 参数 ${CONSUL_TOKEN_PARAM}"
          #keeper添加consul acl配置。
          sed -i "s/--spring.cloud.consul.config.acl-token=.*--/${CONSUL_TOKEN_PARAM} --/" ${configPath}/keeper.yaml
    fi
    if [[ ${resetConsul} -gt 0 ]];then
      if [[ `ps -ef|grep "${installPath}/soft/consul/consul/consul agent"|grep -v grep |wc -l` -gt 0 ]];then
        ps -ef|grep "${installPath}/soft/consul/consul/consul agent"|grep -v grep | awk '{print $2}' | xargs kill -9
        nohup ${installPath}/soft/consul/consul/consul agent -server -data-dir=${installPath}/soft/consul/consul/data/ -node=agent-one -config-dir=${installPath}/soft/consul/consul/config/ -bind=127.0.0.1 -bootstrap-expect=1 -client=0.0.0.0 -ui -log-file=${installPath}/soft/consul/consul/logs/ -log-rotate-bytes=10485760 -log-rotate-max-files=10 &>>${installPath}/soft/consul/log/info.log &
      fi
    fi

  else
    info "开始安装consul "
    #判断是否已解压
    if [[ -d ${installPath}/soft/concul/consul ]]; then
      rm -rf consul
    fi

    #解压
    tar -xf ${workdir}/soft/consul/consul.singlenode.tar.gz -C "${installPath}/soft/consul/"

    #添加consul acl
    echo 'acl = {
      enabled = true
      default_policy = "deny"
      enable_token_persistence = true
    }' > ${installPath}/soft/consul/consul/config/agent.hcl

    #进入目录,执行脚本安装consul
    info "配置consul的IP是:"${localconsulIP}
    mkdir -p ${installPath}/soft/consul/consul/logs
    nohup ${installPath}/soft/consul/consul/consul agent -server -data-dir=${installPath}/soft/consul/consul/data/ -node=agent-one -config-dir=${installPath}/soft/consul/consul/config/ -bind=127.0.0.1 -bootstrap-expect=1 -client=0.0.0.0 -ui -log-file=${installPath}/soft/consul/consul/logs/ -log-rotate-bytes=10485760 -log-rotate-max-files=10 &>>${installPath}/soft/consul/log/info.log &
    #配置环境变量
    homedir=`cd ~ && pwd`
    if [[ ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  ) && ${osVersion} == 8.* ]]; then
        if [[ $(egrep "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" ${homedir}/.bashrc|wc -l) -eq 0 ]];then
            echo "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" >> ${homedir}/.bashrc
            echo "export PATH CLASSPATH JAVA_HOME" >> ${homedir}/.bashrc
        fi
    else
    __ReplaceText ${homedir}/.bashrc "PATH=" "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin"
    __ReplaceText ${homedir}/.bashrc "export" "export PATH CLASSPATH JAVA_HOME"
    fi
    source ${homedir}/.bashrc || true

    sleep 10s

    #生成token并设置环境变量-保证consul cli正常使用
    info "配置consul并生成token文件"
    #生成文件之前判断是否有consultoken.txt文件
    if [[ ! -f ${configPath}/consultoken.txt ]]; then
    ${installPath}/soft/consul/consul/consul acl bootstrap > ${configPath}/consultoken.txt
    fi

    consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
    export CONSUL_HTTP_TOKEN=${consulToken}

    CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
    info "consul 参数 ${CONSUL_TOKEN_PARAM}"
    #keeper添加consul acl配置。
    sed -i "s/--spring.cloud.consul.config.acl-token=.*--/${CONSUL_TOKEN_PARAM} --/" ${configPath}/keeper.yaml

    #检验单节点consul是否部署成功
    checkConsul=$(${installPath}/soft/consul/consul/consul members | wc -l)
    if [ "${checkConsul}" == "2" ]; then
      info "consul install successed"
    else
      info "consul install failed"
      exit 1
    fi
    cd ${workdir}

  fi
  \cp -f script/other/start.sh ${installPath}/soft/consul
  \cp -f script/other/stop.sh ${installPath}/soft/consul

}

function __InitConsulData {
  if [[ $(__readINI nodeconfig/current.cfg service consul) == ${nodeNum} ]]; then
    cd ${workdir}
    consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
    export CONSUL_HTTP_TOKEN=${consulToken}
    info "consulToken=${CONSUL_HTTP_TOKEN}"

    #导入模版数据
    # shellcheck disable=SC2164
    cd "${installPath}/soft/consul/consul"
    info "开始导入模板数据"
    ${installPath}/soft/consul/consul/consul kv import -http-addr=127.0.0.1:8500 @consul_kv.json
    info "模板数据导入完成"
    sleep 20s
    checkImport=$(echo $?)
    if [ "${checkImport}" == "0" ]; then
      info "import consul data successed"
    else
      info "import consul data failed"
    fi
    #修改ConsulGlobalConfig文件
    __UpdateConsulGlobalConfig ${installNodeType}
    #将配置文件写入到consul中
    __ReadGlobalConfig
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/spring.security.basic.enabled true
    __QueryDatabaseInfo
    if [[ ${installType} == 1 ]];then
      if [[ ${theme} == "zData" ]];then
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/color "blue"
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-management-database/distribute.retry.install "0"
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-management-database/distribute.isRollBack "false"
      else
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/color "light"
      fi
    fi
    if [[ ${databaseType} = "MogDB" && ${installType} = "1" ]];then
      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
        port=($( __readINI zcloud.cfg single "mogdb.port" ))
        mogdbIp=($( __readINI zcloud.cfg single "mogdb.service.ip" ))
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
        port=($( __readINI zcloud.cfg multiple "mogdb.port" ))
        mogdbIp=($( __readINI zcloud.cfg multiple "mogdb.service.ip" ))
      fi
      address=${mogdbIp}:${port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/database.address ${address}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/spring.datasource.driver-class-name org.opengauss.Driver
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/spring.datasource.driverClassName org.opengauss.Driver
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/spring.datasource.url 'jdbc:opengauss://${database.address}/zcloud?currentSchema=${database.name}&socketTimeout=180&tcpKeepAlive=true'

      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.host ${server_ip}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.password ${dbaas_paasword_encode}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.port ${server_port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.user ${dbaas_username}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.host ${server_ip}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.port ${server_port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.username ${dbaas_username}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.password ${dbaas_paasword_encode}
    else
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.host ${server_ip}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.password ${dbaas_paasword_encode}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.port ${server_port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.user ${dbaas_username}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.host ${server_ip}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.port ${server_port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.username ${dbaas_username}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.password ${dbaas_paasword_encode}
    fi
    if [[ ${installNodeType} == "OneNode" ]]; then
      workflowIp=${localIP}
    else
      workflowIp=$( __readINI ${workdir}/zcloud.cfg multiple workflow.ip)
    fi
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.api.excuter.url http://127.0.1:8915
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url http://127.0.0.1:5000
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.lcdpWorkflow.url http://${localIP}:18080
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/database.name lowcodeworkflow
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/dbaas.app_id dbd25d22-be33-4358-8051-0cd4365503d3
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-management-database/lowcode.lcdpWorkflow.url ${localIP}:5001
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/nginx.host ${localIP}
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/atomic_ability.host ${localIP}

     #修改consul的
    if [[ $( __readINI ${currentCfg} service consul )  == 1 ]];then
      if [[ ${osType} = "Kylin_arm" || ${osType} = "Kylin_x86" || ${osType} = "uos_arm" || ${osType} = "uos_x86" || ${osType} = "openEuler_x86" || ${osType} = "openEuler_arm" ]];then
          ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-apiGateWay/lcdp.support False
      fi
    fi
    set +e
    #查询
    buildInfo=`${installPath}/soft/consul/consul/consul kv get zcloudconfig/prod/global/build.info`
    set -e
    #还原客户的consul配置
    __Restore_ConsulConfig
    if [[ ${buildInfo} != '' ]];then
       #写入
       ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/build.info "${buildInfo}"
    fi
    # ONCALL-1034610 删除common-db中的无用配置，统一使用global中的配置
    if [[ `${installPath}/soft/consul/consul/consul kv get zcloudconfig/prod/dbaas-common-db/prometheus.ip |wc -l` -gt 0 ]];then
       ${installPath}/soft/consul/consul/consul kv delete zcloudconfig/prod/dbaas-common-db/prometheus.ip
       ${installPath}/soft/consul/consul/consul kv delete zcloudconfig/prod/dbaas-common-db/prometheus.port
    fi

    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.magicCube.url http://${workflowIp}:18281
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-apiGateWay/lcdpRouteAddress "{\"lcdpWorkflow\":[\"${localIP}:18080\"],\"lcdpPlaybookExecutor\":[\"${workflowIp}:5000\"],\"workflow\":[\"${workflowIp}:5001\"],\"api\":[\"${workflowIp}:5001\"],\"openAPIManager\":[\"${workflowIp}:5001\"],\"magicCube\":[\"${workflowIp}:18281\"]}"
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/logging.level.com.enmo.dbaas.repository.dao
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-monitor/platform.alert.level.map '[{"type": "GoldenDB","levelMap": {"1": 2}},{"type": "OCP","levelMap": {"1": 2, "2": 2}},{"type":"GaussDB","levelMap":{"1":2,"2":2,"3":1,"4":1}}]'
    if [[ ${release} == "standard" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/theme "zcloud标准版"
    fi
    if [[ ${release} == "enterprise" && ${oldRelease} == "standard" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/theme "zcloud"
    fi
    # TAPD-1031662 mogodb数据库socket连接一直hang住，设置连接超时时间
    if [[ ${databaseType} = "MogDB" && ${installType} = "4" ]];then
       ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/spring.datasource.url 'jdbc:opengauss://${database.address}/zcloud?currentSchema=${database.name}&socketTimeout=180&tcpKeepAlive=true'
    fi
    if [[ ${theme} == "zData" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/theme "zData"
    fi
  else
    info "当前节点无需配置consul数据"

  fi
}


#读取配置文件
function __ReadGlobalConfig() {
  #   SAVEIFS=$IFS
  #   IFS=$(echo -en "\n")
  info "配置文件目录${installPath}/soft/consul/consul"
  cd ${workdir}
  if [[ ${installNodeType} == "OneNode" ]]; then
    localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
  else
    localIP=$( __readINI zcloud.cfg multiple web.ip )
  fi

  cat ${installPath}/soft/consul/consul/globalconfig.txt | while read line; do
    info "consul kv put $line"
    #   IFS=$SAVEIFS
    ${installPath}/soft/consul/consul/consul kv put $line
  done
  ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/eureka.client.serviceUrl.defaultZone http://admin:admin123@${localIP}:8761/eureka/
  sleep 3s
  check=$(echo $?)
  if [ "${check}" == "0" ]; then
    info "consul kv put zcloudconfig/prod/global/eureka.client.serviceUrl.defaultZone http://${localIP}:8761/eureka/"
  else
    info "consul zcloudconfig/prod/global/eureka.client.serviceUrl.defaultZone error"
    exit 1
  fi
  info "global配置文件替换完成"
  info "切换到工作目录:"${workdir}
  cd ${workdir}
}

function __UpdateConsulGlobalConfig() {
  typeset -r nodeType=${1}

  cd ${installPath}
  info "当前的路径为："${installPath}
  zcloudCfg=${workdir}/zcloud.cfg
  currentCfg=${workdir}/nodeconfig/current.cfg

  if [[ ${installNodeType} == "OneNode" ]]; then
    if [[ ${databaseType} = "MogDB" ]];then
      dependenceOutside=($( __readINI ${zcloudCfg} single "dependence.outside.mogdb" ))
      dbaas_username=$( __readINI ${zcloudCfg} single "mogdb.user" )
      dbaas_paasword=$(__readINI ${zcloudCfg} single mogdb.password)
      if [[ ${dependenceOutside} = "1" ]];then
        server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
      else
        server_ip=${hostIp}
      fi
      server_port=($(__readINI ${zcloudCfg} single mogdb.port))
    else
      dependenceOutside=($( __readINI ${zcloudCfg} single "dependence.outside.mysql" ))
      dbaas_username=$( __readINI ${zcloudCfg} single "mysql.username" )
      dbaas_paasword=$(__readINI ${zcloudCfg} single mysql.root.paasword)
      if [[ ${dependenceOutside} = "1" ]];then
        server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
      else
        server_ip=${hostIp}
      fi
      #server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
      server_port=($(__readINI ${zcloudCfg} single mysql.service.port))
    fi
    localIP=$( __ReadValue ${workdir}/nodeconfig/installparam.txt hostIp)

    #server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
    prometheusIp=$( __readINI ${zcloudCfg} single "prometheus.service.ip" )
    slowmonMgrIp=$( __ReadValue ${workdir}/nodeconfig/installparam.txt hostIp)
  else
    if [[ ${databaseType} = "MogDB" ]];then
      dependenceOutside=($( __readINI ${zcloudCfg} multiple "dependence.outside.mogdb" ))
      dbaas_username=$( __readINI ${zcloudCfg} multiple "mogdb.user" )
      dbaas_paasword=$(__readINI ${zcloudCfg} multiple mogdb.password)
      if [[ ${dependenceOutside} = "1" ]];then
        server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
      else
        server_ip=${hostIp}
      fi
      server_port=($(__readINI ${zcloudCfg} multiple mogdb.port))
    else
      dependenceOutside=($( __readINI ${zcloudCfg} multiple "dependence.outside.mysql" ))
      dbaas_username=$( __readINI ${zcloudCfg} multiple "mysql.username" )
      dbaas_paasword=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
      if [[ ${dependenceOutside} = "1" ]];then
        server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
      else
        server_ip=${hostIp}
      fi
      server_port=($(__readINI ${zcloudCfg} multiple mysql.service.port))
    fi
    localIP=$( __readINI ${zcloudCfg} multiple web.ip )
    prometheusIp=$( __readINI ${zcloudCfg} multiple "prometheus.service.ip" )
    slowmonMgrIp=$( __readINI ${zcloudCfg} multiple web.ip )
  fi
  dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_paasword}`
  #修改consul的globalconfig.txt文件的eureka.client.serviceUrl
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    
    sed -i "s#^zcloudconfig/prod/global/eureka.client.serviceUrl.defaultZone.*#zcloudconfig/prod/global/eureka.client.serviceUrl.defaultZone http://${localIP}:8761/eureka/#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的spring.datasource.username
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/global/spring.datasource.username.*#zcloudconfig/prod/global/spring.datasource.username ${dbaas_username}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的spring.datasource.url
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    
    basename='${database.name}'
    dbaddress='${database.address}'
    sed -i "s#^zcloudconfig/prod/global/spring.datasource.url.*#zcloudconfig/prod/global/spring.datasource.url jdbc:mysql://${dbaddress}/${basename}?characterEncoding=UTF-8\&autoReconnect=true\&allowMultiQueries=true\&serverTimezone=GMT%2B8#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的spring.datasource.password
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/global/spring.datasource.password.*#zcloudconfig/prod/global/spring.datasource.password ${dbaas_paasword_encode}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的database.address
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/global/database.address.*#zcloudconfig/prod/global/database.address ${server_ip}:${server_port}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的altermanager.ip
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    
    sed -i "s#^zcloudconfig/prod/dbaas-monitor/altermanager.ip.*#zcloudconfig/prod/dbaas-monitor/altermanager.ip ${prometheusIp}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的dbaas.monitor.ip
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/dbaas-monitor/dbaas.monitor.ip.*#zcloudconfig/prod/dbaas-monitor/dbaas.monitor.ip ${localIP}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的prometheus.ip
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    
    sed -i "s#^zcloudconfig/prod/global/prometheus.ip.*#zcloudconfig/prod/global/prometheus.ip ${prometheusIp}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的zoramon.ip
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/dbaas-monitor/zoramon.ip.*#zcloudconfig/prod/dbaas-monitor/zoramon.ip ${localIP}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的alertmanagerIp.port
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/dbaas-registrationhub/alertmanagerIp.port.*#zcloudconfig/prod/dbaas-registrationhub/alertmanagerIp.port ${prometheusIp}:8094#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的dbassMonitor.ip.port
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/dbaas-registrationhub/dbassMonitor.ip.port.*#zcloudconfig/prod/dbaas-registrationhub/dbassMonitor.ip.port ${localIP}:8091#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的prometheusIp.port
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/dbaas-registrationhub/prometheusIp.port.*#zcloudconfig/prod/dbaas-registrationhub/prometheusIp.port ${prometheusIp}:8093#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的slowmon.mgr.ip
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/global/slowmon.mgr.ip.*#zcloudconfig/prod/global/slowmon.mgr.ip ${slowmonMgrIp}#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的cdjar.home
  cdjar_home=${installPath}
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/global/cdjar.home.*#zcloudconfig/prod/global/cdjar.home ${cdjar_home}#g" soft/consul/consul/globalconfig.txt
  fi
  #修改consul的globalconfig.txt文件的zcloudconfig/prod/logging.config
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/global/logging.config.*#zcloudconfig/prod/global/logging.config ${cdjar_home}/\${spring.application.name}/config/logback.xml#g" soft/consul/consul/globalconfig.txt
  fi
  #修改consul的globalconfig.txt文件的zcloudconfig/prod/global/prometheus.install.path
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/global/prometheus.install.path.*#zcloudconfig/prod/global/prometheus.install.path ${cdjar_home}/prometheus#g" soft/consul/consul/globalconfig.txt
  fi
  #修改consul的globalconfig.txt文件的zcloudconfig/prod/dbaas-registrationhub/alertmanager.file
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/dbaas-registrationhub/alertmanager.file.*#zcloudconfig/prod/dbaas-registrationhub/alertmanager.file ${cdjar_home}/alertmanager/alertmanager.yml#g" soft/consul/consul/globalconfig.txt
  fi
  #修改consul的globalconfig.txt文件的zcloudconfig/prod/dbaas-registrationhub/zm_mgr.host
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/dbaas-registrationhub/zm_mgr.host.*#zcloudconfig/prod/dbaas-registrationhub/zm_mgr.host  ${localIP}#g" soft/consul/consul/globalconfig.txt
  fi
  #修改consul的globalconfig.txt文件的zcloudconfig/prod/dbaas-monitor/api.gateway
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then
    sed -i "s#^zcloudconfig/prod/dbaas-monitor/api.gateway.*#zcloudconfig/prod/dbaas-monitor/api.gateway http://${localIP}:8080#g" soft/consul/consul/globalconfig.txt
  fi

  #修改consul的globalconfig.txt文件的zcloudconfig/prod/global/nginx.product.image.path
  if [[ $(__readINI ${currentCfg} service consul) == 1 ]]; then

    sed -i "s#^zcloudconfig/prod/global/nginx.product.image.path.*#zcloudconfig/prod/global/nginx.product.image.path ${cdjar_home}/soft/nginx/nginx/static/image/#g" soft/consul/consul/globalconfig.txt
  fi

   #修改consul的globalconfig.txt文件的zcloudconfig/prod/dbaas-registrationhub/prometheus.install.path
    if [[ $( __readINI ${currentCfg} service consul )  == 1 ]]; then
       sed -i "s#^zcloudconfig/prod/dbaas-registrationhub/prometheus.install.path.*#zcloudconfig/prod/dbaas-registrationhub/prometheus.install.path ${cdjar_home}/prometheus#g" soft/consul/consul/globalconfig.txt
    fi

}

function __Restore_ConsulConfig {
  if [[ ${installNodeType} == "OneNode" ]]; then
    localIP=$( __ReadValue nodeconfig/installparam.txt hostIp)
  else
    localIP=$( __readINI zcloud.cfg multiple web.ip )
  fi

  if [[ ${installType} != 1 ]];then
    cd ${installPath}/soft/consul/consul
    bakTimePath=($( __ReadValue ${logPath}/evn.cfg bakTimePath))
    cp ${bakTimePath}/consul_kv.json consul_kv.json.bak
    ${installPath}/soft/consul/consul/consul kv import -http-addr=127.0.0.1:8500 @consul_kv.json.bak
    if [[ ${installType} = 2 ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/logging.config ${installPath}/\${spring.application.name}/config/logback.xml
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-registrationhub/alertmanager.file ${installPath}/alertmanager/alertmanager.yml
      if [[ `ps -ef|grep prometheus/|grep -v grep|wc -l ` -gt 0 ]];then
        prometheusHome=`ps -ef|grep prometheus/|grep -v grep |awk -F' ' '{print $8}'|awk -F'/' 'OFS="/" {$NF="";print $0}'`
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-registrationhub/prometheus.install.path ${prometheusHome}
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/prometheus.install.path ${prometheusHome}
      fi
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-monitor/api.gateway  http://${localIP}:8080
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-registrationhub/zm_mgr.host  ${localIP}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/nginx.product.image.path  ${cdjar_home}/soft/nginx/nginx/static/image/
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-registrationhub/alertmanager.parent.route.group_by  objId,alertname,firstLabel,secondLabel,thirdLabel,fourthLabel
    fi
    #有变更的请写在下面
    version=`cat ${workdir}/version.txt`
    oldVersion=$( __ReadValue ${logPath}/evn.cfg oldVersion)
    if [[ (${oldVersion} != "" && ${oldVersion} < "3.5.0") || ${version} = "3.5.0" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-monitor/alert.topSql.execute.cron   "0 */5 * * * ?"
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-infrastructure/other.function.data  "[{\"name\":\"告警中心\",\"functionId\":\"alertCenter\", \"description\":\"实时监测，精准定位，极速响应\"}, {\"name\":\"脚本中心\",\"functionId\":\"scriptList\", \"description\":\"高效安全的运维脚本工具\"},{\"name\":\"用户管理\",\"functionId\":\"user\", \"description\":\"便捷安全的权限分配管理\"}]"
    fi
    if [[ (${oldVersion} != "" && ${oldVersion} < "3.5.1") || ${version} = "3.5.1" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-infrastructure/standingBook.cleaUp.cron  "0 0 0 * * ?"
    fi
    if [[ (${oldVersion} != "" && ${oldVersion} < "3.5.2") || ${version} = "3.5.2" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-registrationhub/prometheus.install.path ${installPath}/prometheus
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/global/prometheus.install.path ${installPath}/prometheus
    fi
    info "还原客户的consul配置完成"
  fi
}

function __InstallConsulUnRoot() {
  if [[  $( __readINI nodeconfig/current.cfg service consul ) == ${nodeNum} ]]; then
    __InstallConsul

  else
    info "当前节点无需安装consul"
    #针对其他节点，需要修改启动命令，并添加配置到${configPath}/consultoken.txt

    consulToken=$( __readINI zcloud.cfg multiple consul.acl.token )
    CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
    info "consul 参数 ${CONSUL_TOKEN_PARAM}"
    sed -i "s/--spring.cloud.consul.config.acl-token=.*--/${CONSUL_TOKEN_PARAM} --/" ${configPath}/keeper.yaml

    echo "SecretID ${consulToken}" > ${configPath}/consultoken.txt
  fi

  #生成配置文件
  consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
  info "替换安装配置文件的consul.acl.token值为${consulToken} "
  cp zcloudBeforeInstall.cfg zcloudBeforeInstall.cfg_temp
  sed -i "/^consul.acl.token/cconsul.acl.token=${consulToken}" zcloudBeforeInstall.cfg_temp

}

__InstallConsulUnRoot
__InitConsulData