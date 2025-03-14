
. ./script/lib/common_unroot.sh

function __StartService() {
  env=($(__readINI zcloud.cfg common "spring.profiles.active"))
  if [[ ${installNodeType} == "OneNode" ]]; then
          consulHost=$( __ReadValue nodeconfig/installparam.txt hostIp)
  else
          consulHost=$( __readINI zcloud.cfg multiple consul.host )
  fi

  consulPort=($(__readINI zcloud.cfg common "consul.port"))
  watchEnable=($(__readINI zcloud.cfg common "consul.watch.enable"))

  if [[ -f ${configPath}/consultoken.txt ]]; then
  consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
  CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
  fi

  jarDir=${1}
  jarName=${2}
  if [[ ${jarName} == "dbaas-apigateway" ]]; then
    jarName="dbaas-apiGateWay"
  fi

  jarPath=$(ls -t ${installPath}/${jarDir}/${jarName}*.jar | head -n 1)
  source ${homePath}/.bashrc || true
  javapath=$(echo $JAVA_HOME)/bin/java

  memorySize=`free -h|grep Mem|awk '{print $2}'|sed -r "s/G$|Gi$//g"|awk -F'.' '{print $1}'`
  if [[ ${installNodeType} == "TwoNodes" ]]; then
    memorySize=$[${memorySize}*2]
  elif [[ ${installNodeType} == "FourNodes" ]]; then
    memorySize=$[${memorySize}*4]
  fi

  jvmTemplate="32G"
  if [[ ${memorySize} -lt 60 ]];then
    jvmTemplate="32G"
  elif [[ ${memorySize} -lt 120 ]];then
    jvmTemplate="64G"
  elif [[  ${memorySize} -lt 248 ]];then
    jvmTemplate="128G"
  else
    jvmTemplate="256G"
  fi
  if [[ ${jarDir} =~ aicure ]];then
    serviceName=`echo ${jarDir}|awk -F'/' '{print $NF}'`
  else
    serviceName=${jarDir}
  fi
  jvmParam=($(__readINI script/jvm_param/jvm_template.cfg ${jvmTemplate} ${serviceName}))
  jvmMin=`echo ${jvmParam}|awk -F'/' '{print $1}'`
  jvmMax=`echo ${jvmParam}|awk -F'/' '{print $NF}'`
  if [[ `echo ${jvmMax} |egrep "^([1-9][0-9]*|-[1-9][0-9]*)$" |wc -l` = 0 || `echo ${jvmMin} |egrep "^([1-9][0-9]*|-[1-9][0-9]*)$"|wc -l` = 0 ]];then
    jvmMax=512
    jvmMin=256
  fi
  if [[ ${jvmMin} -gt ${jvmMax} ]];then
    info "${jarName}配置参数为-Xms${jvmMin}m -Xmx${jvmMax}m, 最小值大于了最大值，使用默认jvm 参数-Xms256m -Xmx512m"
    jvmMax=512
    jvmMin=256
  fi

  if [[ ${serviceName} == "zdbmon-mgr" ]];then
    runcmd="-Xms${jvmMin}m -Xmx${jvmMax}m --add-opens java.base/java.lang=ALL-UNNAMED -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/${jarName}_%p.log -Duser.timezone=GMT+08"
    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
    if [[ $serviceNameLine != "" ]];then
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      path=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n path:|head -n 1|awk -F':' '{print $3}'`
      if [[ `cat ${keeperConf} |grep 'add-opens java.base/java.nio=ALL-UNNAMED' | wc -l` == 0 ]];then
        sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|-Djava.io.tmpdir=|--add-opens java.base/java.lang=ALL-UNNAMED -Djava.io.tmpdir=|g" ${keeperConf}
      fi
    fi
  elif [[  ${serviceName} == "dbaas-common-db" ]]; then
    runcmd="-Xms${jvmMin}m -Xmx${jvmMax}m --add-opens java.base/java.util=ALL-UNNAMED -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/${jarName}_%p.log -Duser.timezone=GMT+08"
    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
    if [[ $serviceNameLine != "" ]];then
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      path=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n path:|head -n 1|awk -F':' '{print $3}'`
      if [[ `cat ${keeperConf} |grep 'add-opens java.base/java.util=ALL-UNNAMED' | wc -l` == 0 ]];then
        sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|-Djava.io.tmpdir=|--add-opens java.base/java.util=ALL-UNNAMED -Djava.io.tmpdir=|g" ${keeperConf}
      fi
    fi
  else
    runcmd="-Xms${jvmMin}m -Xmx${jvmMax}m -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/${jarName}_%p.log -Duser.timezone=GMT+08"
  fi

  keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
  if [[ ${installType} = 1 && $serviceNameLine != "" ]];then
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    path=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n path:|head -n 1|awk -F':' '{print $3}'`
    sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xms[0-9]*m|-Xms${jvmMin}m|g" ${keeperConf}
    sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xmx[0-9]*m|-Xmx${jvmMax}m|g" ${keeperConf}
  fi
  if [[ ${installType} = 4 && $serviceNameLine != "" ]];then
    xmsJvm=$(__queryJvmXms ${serviceName})
    xmxJvm=$(__queryJvmXmx ${serviceName})
    info "xmsJvm=${xmsJvm}"
    info "xmxJvm=${xmxJvm}"
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    if [[ ${xmsJvm} != '' ]];then
      sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xms[0-9]*m|${xmsJvm}|g" ${keeperConf}
    fi
    if [[ ${xmxJvm} != '' ]];then
      sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xmx[0-9]*m|${xmxJvm}|g" ${keeperConf}
    fi
  fi

  if [[ ${jarName} == "dbaas-eureka-server" ]];then
    cd ${installPath}
    sed -ri "s|${installPath}/${jarDir}/.*\.jar|${jarPath}|g" ${configPath}/keeper.yaml
    __startFromKeeper ${jarName}
    cd ${homePath}
  else
    if [[ ${jarDir} == "dbaas-doc-retrieval" ]];then
      cd ${installPath}/${jarDir}
    else
      cd ${installPath}
    fi
    if [[ ${jarDir} == "dbaas-infrastructure" ]];then
      cp -f  ${workdir}/soft/chisel/chisel ${installPath}/dbaas-infrastructure/
      chmod 775 ${installPath}/dbaas-infrastructure/chisel
    fi
    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
    if [[ ${serviceNameLine} = "" ]];then
      serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}/conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p"  ${workdir}/conf/keeper.yaml>temp.yaml
      endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
      sed -i "${endLine}r temp.yaml" ${keeperConf}
      rm -f temp.yaml

      if [[ ${installNodeType} == "OneNode" ]]; then
          hostIp=$( __ReadValue ${workdir}/nodeconfig/installparam.txt hostIp)
      else
          hostIp=$( __readINI ${workdir}/zcloud.cfg multiple consul.host )
      fi
      consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
      sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
      sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
      sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
      sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
    else
      enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
      lineNum=$[ ${serviceNameLine} + ${offset} ]
      sed -ri "${lineNum}s|enable: .*|enable: true|g" ${keeperConf}
    fi
    sed -ri "s|${installPath}/${jarDir}/.*\.jar|${jarPath}|g" ${configPath}/keeper.yaml
    __startFromKeeper  ${serviceName}
    let count+=1
    if [[ $[${count}%15] = 0 ]];then
      info "等待服务的启动，sleep 120"
      sleep 120
    fi
    cd ${homePath}
  fi

  cd ${workdir}
}

function __InstallService() {
  serviceName=${1}
  serviceNamePrefix=${2}
  if [[  $( __readINI nodeconfig/current.cfg service ${serviceName} ) == ${nodeNum} ]]; then
    if [[ ${release} == "standard" && (${serviceName} == "dbaas-api-create-dg" || ${serviceName} == "dbaas-create-shardingsphere" || ${serviceName} == "dbaas-common-backupcenter" ) ]];then
      return
    fi

    __UpdateFlowWorkConsul ${serviceName}

    echo "[${serviceName}]">>${versionPath}/version.cfg
    if [[ ! -e ${installPath}${serviceNamePrefix}/${serviceName} ]]; then
      echo "type=全新安装">>${versionPath}/version.cfg
      echo "newVersion=${nowVersion}">>${versionPath}/version.cfg
      cp -r "jar${serviceNamePrefix}/${serviceName}/" "${installPath}${serviceNamePrefix}/"
      info "${installPath}${serviceNamePrefix}/${serviceName}/config"
      if [[ ! -d ${installPath}${serviceNamePrefix}/${serviceName}/config ]];then
        info "mkdir -p ${installPath}${serviceNamePrefix}/${serviceName}/config"
        mkdir -p ${installPath}${serviceNamePrefix}/${serviceName}/config
      fi
      if [[ ${serviceName} == "dbaas-monitor" ]];then
        tar -xf ${workdir}/jar/prometheus.tar.gz -C ${workdir}/jar
        \cp -f ${workdir}/jar/prometheus/promtool ${installPath}${serviceNamePrefix}/${serviceName}
        chmod u+x ${installPath}${serviceNamePrefix}/${serviceName}/promtool
      fi
      # 配置日志脱敏的服务,暂时只做了infrastructure和db-manage
      if [[ ${theme} == "zData" ]];then
        if [[ ${serviceName} == "dbaas-apigateway" ]]; then
          cp conf/logback/logback-${serviceName}-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}${serviceNamePrefix}/${serviceName}'/"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-${serviceName}-zdata.xml
          mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-${serviceName}-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml
        elif [[ ${serviceName} == "dbaas-flyway-manage" || ${serviceName} == "dbaas-eureka-server" || ${serviceName} == "task-management" ]]; then
          cp conf/logback/logback-default-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/
          info "sed -i 's#name=\"logHome\" value=.*#name=\"logHome\" value=\"'${logPath}${serviceNamePrefix}/${serviceName}'/\"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-zdata.xml"
          info "mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml"
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}${serviceNamePrefix}/${serviceName}'/"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-zdata.xml
          mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml
        else
          cp conf/logback/logback-default-with-mask-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/
          info "sed -i 's#name=\"logHome\" value=.*#name=\"logHome\" value=\"'${logPath}${serviceNamePrefix}/${serviceName}'/\"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-with-mask-zdata.xml"
          info "mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-with-mask-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml"
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}${serviceNamePrefix}/${serviceName}'/"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-with-mask-zdata.xml
          mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-with-mask-zdata.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml
        fi
      else
        if [[ ${app} == "dbaas-db-manage" ]]; then
          cp conf/logback/logback-default-with-mask.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}${serviceNamePrefix}/${serviceName}'/"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-with-mask.xml
          mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default-with-mask.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml
        elif [ -f conf/logback/logback-${serviceName}.xml ]; then
          cp conf/logback/logback-${serviceName}.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}${serviceNamePrefix}/${serviceName}'/"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-${serviceName}.xml
          mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-${serviceName}.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml
        else
          cp conf/logback/logback-default.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}${serviceNamePrefix}/${serviceName}'/"/>#g' ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default.xml
          mv ${installPath}${serviceNamePrefix}/${serviceName}/config/logback-default.xml ${installPath}${serviceNamePrefix}/${serviceName}/config/logback.xml
        fi
      fi

      port=$(__CheckPort ${serviceName})
      if [[ ${port} -gt 0 ]];then
        error "${port}端口已被占用，${serviceName}安装失败,安装中断"
        exit 1
      fi

      __StartService "${serviceNamePrefix}${serviceName}" "${serviceName}"
    else
      if [[ ${serviceName} == "dbaas-apigateway" ]]; then
        serviceJarName="dbaas-apiGateWay"
      else
        serviceJarName=${serviceName}
      fi
      if [[ ${serviceName} == "dbaas-monitor" ]];then
        tar -xf ${workdir}/jar/prometheus.tar.gz -C ${workdir}/jar
        \cp -f ${workdir}/jar/prometheus/promtool ${installPath}${serviceNamePrefix}/${serviceName}
        chmod u+x ${installPath}${serviceNamePrefix}/${serviceName}/promtool
      fi
      nowVersion=$(ls jar${serviceNamePrefix}/${serviceName}/${serviceJarName}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      oldVersion=$(ls ${installPath}${serviceNamePrefix}/${serviceName}/${serviceJarName}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      if [[ ${nowVersion} != ${oldVersion} || "dbaas-apigateway" == ${serviceName} || "dbaas-monitor" == ${serviceName}  || "dbaas-infrastructure" == ${serviceName} ]]; then
        echo "type=升级替换">>${versionPath}/version.cfg
        echo "newVersion=${nowVersion}">>${versionPath}/version.cfg
        echo "oldVersion=${oldVersion}">>${versionPath}/version.cfg
        jarName=$(ls ${installPath}${serviceNamePrefix}/${serviceName}/${serviceJarName}*.jar | awk -F'/' '{print $NF}')

        if [[ $(ps -ef | grep ${serviceName}/${serviceJarName} | grep -v grep | wc -l) -gt 0 ]]; then
          echo "原安装包运行状态=active">>${versionPath}/version.cfg
          ps -ef | grep ${serviceName}/${serviceJarName} | grep -v grep | awk '{print $2}' | xargs kill -9
          info "关闭${serviceName}成功"
          sleep 2s
        else
          echo "原安装包运行状态=inactive">>${versionPath}/version.cfg
        fi
        port=$(__CheckPort ${serviceName})
        if [[ ${port} -gt 0 ]];then
          error "${port}端口已被占用，${serviceName}安装失败,安装中断"
          exit 1
        fi
        mv ${installPath}${serviceNamePrefix}/${serviceName}/${jarName} ${installPath}${serviceNamePrefix}/${serviceName}/${jarName}.bak
        cp jar${serviceNamePrefix}/${serviceName}/${serviceJarName}*.jar ${installPath}${serviceNamePrefix}/${serviceName}/
        rm -f ${installPath}${serviceNamePrefix}/${serviceName}/config/messages*
        info "复制${serviceName}到安装目录"
        __StartService "${serviceNamePrefix}${serviceName}" "${serviceName}"
        info "重启${serviceName}成功"
      else
        echo "type=升级替换">>${versionPath}/version.cfg
        echo "newVersion=${nowVersion}">>${versionPath}/version.cfg
        echo "oldVersion=${oldVersion}">>${versionPath}/version.cfg
        if [[ $(ps -ef | grep ${serviceName}/${serviceJarName} | grep -v grep | wc -l) == 0 ]]; then
          echo "原安装包运行状态=inactive">>${versionPath}/version.cfg
          info "原服务${serviceName}已停止，需要重新启动成功"
          port=$(__CheckPort ${serviceName})
          if [[ ${port} -gt 0 ]];then
            error "${port}端口已被占用，${serviceName}安装失败,安装中断"
            exit 1
          fi
          __StartService "${serviceNamePrefix}${serviceName}" "${serviceName}"
          info "重启${serviceName}成功"
        else
          echo "原安装包运行状态=active">>${versionPath}/version.cfg
          info "${serviceName}版本没有变化，且处于正常的运行状态，无需处理"
        fi
      fi
    fi
    \cp -f script/start.sh ${installPath}/${serviceName}
    \cp -f script/stop.sh ${installPath}/${serviceName}
    info "[${serviceName}]  安装完成"
  else
        info "当前节点无需安装${serviceName}"
  fi
}

function __UpdateFlowWorkConsul() {
  serviceName=$1
  consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
  if [[ ${installNodeType} == "OneNode" ]]; then
    consulIp=${hostIp}
  else
    consulIp=$( __readINI zcloud.cfg multiple consul.host )
  fi
  if [[ ${serviceName} == "dbaas-lowcode-atomic-ability" && ${installType} == 2 ]];then
    sed -i "s/8914/8916/g" ${installPath}/dbaas-lowcode-atomic-ability/config/application.properties
  fi

  if [[ ${serviceName} == "task-management" ]];then
    curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/task_management.host?dc=dc1
  fi
  if [[ ${serviceName} == "dbaas-permissions" ]];then
    curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/dbaas_permissions.host?dc=dc1
  fi

}

function __CheckZcloudServiceStatus()  {
  if [[ -d ${installPath}/dbaas-apigateway && ${serviceName} == "dbaas-apigateway" ]];then
    su - zcloud -c"cd ${installPath};./start.sh --name dbaas-apigateway"
  fi
  if [[ -d ${installPath}/magic_cube && ${serviceName} == "magic-cube"  ]];then
    su - zcloud -c"cd ${installPath};./start.sh --name magic-cube"
  fi
  if [[ -d ${installPath}/ansible_executor && ${serviceName} == "ansible_executor"  ]];then
    su - zcloud -c"cd ${installPath};./start.sh --name ansible_executor"
  fi
  info "Loop check three times"
  for loop in 1 2 3
  do
    info "start num ${loop} check"
    info "Wait 2 minutes for the service to start"
      #睡眠2分钟
    sleep 120s
  if [[ ${installNodeType} == "OneNode" ]]; then
    eurekaIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
  else
    eurekaIp=$( __readINI zcloud.cfg multiple web.ip )
  fi

    result=`curl -u admin:admin123 http://${eurekaIp}:8761/eureka/apps`
    if [[ "${result}" == "" ]] ;then
        echo "连接eureka异常，请检查eureka节点防火墙是否关闭"
    else
      upapps=$(echo ${result}|awk -F'[<>]' '{for(i=1;i<=NF;i++){
      if($i=="app"){appname=$(i+1)};
      if($i=="status" && $(i+1)=="UP"){print appname}
      }}')
      downApp=0
      for app  in  `ls ${installPath}  | egrep -v 'agent|zdbmon-mgr|keeper|zcloud-zoramon-mgr|aicure|dbaas-eureka-server|prometheus|alertmanager|slowmon_mgr|smart_baseline|dbaas-mail-sender|dbaas-registrationHub|soft|readme|start.sh|stop.sh|packages|version.txt|installparam.txt|serviceTemp|ansible_executor|DBaas-Lowcode-WorkFlow|open_workflow|magic_cube|zcloud_release.txt|dbType.txt|pub_libs|dbaas-wxwork-sender|dbaas-sender-common|dbaas-zabbix-sender|podman|magic-script-executor|logPath_IS_UNDEFINED|node-exporter|dbaas-operate-db|dbaas-monitor-dashboard|dbaas-api-create-dg|dbaas-configuration|dbaas-oceanbase|dbaas-backend-sql-server|dbaas-backend-db2|dbaas-backend-damengdb|dbaas-create-mongodb|dbaas-create-postgres|dbaas-create-redis|dbaas-create-shardingsphere|dbaas-lowcode-http-engine'`; do
        if [[ $app == "expert-knowledge-base" ]];then
          app="expert-knwl-base"
        fi
        cnt=$(echo "$upapps"|grep -i $app|wc -l)
        if [[ $cnt -eq 0 ]]; then
          info "app not start:$app"; downApp=`expr $downApp + 1`;
#          if [[  ${app} == "dbaas-apigateway" ]];then
#            su - zcloud -c"cd ${installPath};./start.sh --name dbaas-apigateway"
#          fi
        fi
      done
      if [ ${downApp} == 0 ];then
        break
      fi
    fi

  done

}

function __ChangeZcloudCfg() {
    #修改zcloud配置文件的内容：取消明文展示密码
    zcloudCfg=${workdir}/zcloud.cfg
    if [[ ${installNodeType} == "OneNode" ]]; then
              __mysqlRootPwd=$(__readINI ${zcloudCfg} single mysql.root.paasword)
    else
              __mysqlRootPwd=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
    fi

    if [[ "${dbaas_paasword}" != "" ]];then
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_paasword}`
    fi
    #任务中心密码
    taskmanagement_paasword=($( __readINI zcloud.cfg common "mysql.server.taskmanagement.password" ))
    if [[ "${taskmanagement_paasword}" != "" ]];then
    taskmanagement_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${taskmanagement_paasword}`
    fi
    #dbaas用户密码
    dbaas_user_paasword=($( __readINI zcloud.cfg common "mysql.server.dbaas.paasword" ))
    if [[ "${dbaas_user_paasword}" != "" ]];then
    dbaas_user_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils  encode ${dbaas_user_paasword}`
    fi
    #activiti密码
    activiti_paasword=($( __readINI zcloud.cfg common "mysql.server.activiti.paasword" ))
    if [[ "${activiti_paasword}" != "" ]];then
    activiti_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${activiti_paasword}`
    fi
    #scheduler密码
    scheduler_paasword=($( __readINI zcloud.cfg common "mysql.server.scheduler.paasword" ))
    if [[ "${scheduler_paasword}" != "" ]];then
    scheduler_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${scheduler_paasword}`
    fi
    #monitormanager密码
    monitormanager_paasword=($( __readINI zcloud.cfg common "mysql.server.monitormanager.paasword" ))
    if [[ "${monitormanager_paasword}" != "" ]];then
    monitormanager_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${monitormanager_paasword}`
     fi
     #script_center密码
     script_center_paasword=($( __readINI zcloud.cfg common "mysql.server.dbaas_script_center.password" ))
     if [[ "${script_center_paasword}" != "" ]];then
     script_center_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${script_center_paasword}`
     fi
     #aicure密码
     aicure_paasword=($( __readINI zcloud.cfg common "aicure.influx.password" ))
     if [[ "${aicure_paasword}" != "" ]];then
     aicure_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${aicure_paasword}`
     fi

    mogdb_password=($( __readINI zcloud.cfg single "mogdb.password" ))
    if [[ "${mogdb_Password}" != "" ]];then
     mogdb_password_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${mogdb_Password}`
    fi
    mogdb_password1=($( __readINI zcloud.cfg multiple "mogdb.password" ))
    if [[ "${mogdb_password1}" != "" ]];then
     mogdb_password_encode1=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${mogdb_password1}`
    fi

    #mysql-root密码
    sed -i "/^mysql.root.paasword/cmysql.root.paasword=${dbaas_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.root.paasword/cmysql.root.paasword=${dbaas_paasword_encode}" zcloud.cfg
    #mogdb 密碼
    sed -i "/^mogdb.password/cmogdb.password=${mogdb_password_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mogdb.password/cmogdb.password=${mogdb_password_encode}" zcloud.cfg

    #任务中心密码
    sed -i "/^mysql.server.taskmanagement.password/cmysql.server.taskmanagement.password=${taskmanagement_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.taskmanagement.password/cmysql.server.taskmanagement.password=${taskmanagement_paasword_encode}" zcloud.cfg

    #dbaas用户密码
    sed -i "/^mysql.server.dbaas.paasword/cmysql.server.dbaas.paasword=${dbaas_user_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.dbaas.paasword/cmysql.server.dbaas.paasword=${dbaas_user_paasword_encode}" zcloud.cfg

    #activiti密码
    sed -i "/^mysql.server.activiti.paasword/cmysql.server.activiti.paasword=${activiti_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.activiti.paasword/cmysql.server.activiti.paasword=${activiti_paasword_encode}" zcloud.cfg

    #scheduler密码
    sed -i "/^mysql.server.scheduler.paasword/cmysql.server.scheduler.paasword=${scheduler_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.scheduler.paasword/cmysql.server.scheduler.paasword=${scheduler_paasword_encode}" zcloud.cfg

    #monitormanager密码
    sed -i "/^mysql.server.monitormanager.paasword/cmysql.server.monitormanager.paasword=${monitormanager_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.monitormanager.paasword/cmysql.server.monitormanager.paasword=${monitormanager_paasword_encode}" zcloud.cfg

    #script_center密码
    sed -i "/^mysql.server.dbaas_script_center.password/cmysql.server.dbaas_script_center.password=${script_center_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.dbaas_script_center.password/cmysql.server.dbaas_script_center.password=${script_center_paasword_encode}" zcloud.cfg

    #aicure密码
    sed -i "/^aicure.influx.password/caicure.influx.password=${aicure_paasword_encode}" zcloudBeforeInstall.cfg
    sed -i "/^aicure.influx.password/caicure.influx.password=${aicure_paasword_encode}" zcloud.cfg


    cd ${installPath}
    version=`cat version.txt`
    sed -i "/^mysql.root.paasword/cmysql.root.paasword=${dbaas_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mysql.root.paasword/cmysql.root.paasword=${dbaas_paasword_encode}" ${packagePath}/${version}/zcloud.cfg

    sed -i "/^mogdb.password/cmogdb.password=${mogdb_password_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mogdb.password/cmogdb.password=${mogdb_password_encode}" ${packagePath}/${version}/zcloud.cfg
    sed -i "/^mogdb.password/cmogdb.password=${mogdb_password_encode1}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mogdb.password/cmogdb.password=${mogdb_password_encode1}" ${packagePath}/${version}/zcloud.cfg

    #dbaas用户密码
    sed -i "/^mysql.server.dbaas.paasword/cmysql.server.dbaas.paasword=${dbaas_user_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.dbaas.paasword/cmysql.server.dbaas.paasword=${dbaas_user_paasword_encode}" ${packagePath}/${version}/zcloud.cfg

    #activiti密码
    sed -i "/^mysql.server.activiti.paasword/cmysql.server.activiti.paasword=${activiti_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.activiti.paasword/cmysql.server.activiti.paasword=${activiti_paasword_encode}" ${packagePath}/${version}/zcloud.cfg

    #scheduler密码
    sed -i "/^mysql.server.scheduler.paasword/cmysql.server.scheduler.paasword=${scheduler_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.scheduler.paasword/cmysql.server.scheduler.paasword=${scheduler_paasword_encode}" ${packagePath}/${version}/zcloud.cfg

    #monitormanager密码
    sed -i "/^mysql.server.monitormanager.paasword/cmysql.server.monitormanager.paasword=${monitormanager_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.monitormanager.paasword/cmysql.server.monitormanager.paasword=${monitormanager_paasword_encode}" ${packagePath}/${version}/zcloud.cfg

    #script_center密码
    sed -i "/^mysql.server.dbaas_script_center.password/cmysql.server.dbaas_script_center.password=${script_center_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^mysql.server.dbaas_script_center.password/cmysql.server.dbaas_script_center.password=${script_center_paasword_encode}" ${packagePath}/${version}/zcloud.cfg

    #aicure密码
    sed -i "/^aicure.influx.password/caicure.influx.password=${aicure_paasword_encode}" ${packagePath}/${version}/zcloudBeforeInstall.cfg
    sed -i "/^aicure.influx.password/caicure.influx.password=${aicure_paasword_encode}" ${packagePath}/${version}/zcloud.cfg
    cd ${workdir}

}

function __queryOldRunCmd() {
  oldConf=${configPath}/keeper.xml
  if [[ -f ${oldConf} ]];then
    serviceNameLine=`sed -n "/<serviceName>${serviceName}<\/serviceName>/=" ${oldConf}`
    set +e
    jvmParam=`sed -n $[${serviceNameLine}+2]p ${oldConf} |egrep -o  "\-Xms[0-9]*m \-Xmx[0-9]*m"`
    set -e
    if [[ ${jvmParam} == "" ]];then
      echo ""
    else
      echo "${jvmParam}"
    fi
  else
    echo ""
  fi

}


function __queryJvmXms() {
  serviceName=$1
  set +e
  jvmParam=`ps -ef|grep /${serviceName}/|egrep -o "\-Xms[0-9]*m"`
  set -e
  if [[ ${jvmParam} == "" ]];then
    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperBakPath}`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperBakPath} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    path=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperBakPath} |grep -n path:|head -n 1|awk -F':' '{print $3}'`
    xms=$(echo `sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${keeperBakPath} `|egrep -o "\-Xms[0-9]*m")
    xmsJvm=`echo ${xms} |egrep -o "\-Xms[0-9]*m"`
    echo ${xmsJvm}
  else
    echo ${jvmParam}
  fi
}




function __queryJvmXmx() {
  serviceName=$1
  set +e
  jvmParam=`ps -ef|grep /${serviceName}/|egrep -o "\-Xmx[0-9]*m"`
  set -e
  if [[ ${jvmParam} == "" ]];then
    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperBakPath}`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperBakPath} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    path=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperBakPath} |grep -n path:|head -n 1|awk -F':' '{print $3}'`
    xms=$(echo `sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${keeperBakPath} `|egrep -o "\-Xmx[0-9]*m")
    xmsJvm=`echo ${xms} |egrep -o "\-Xmx[0-9]*m"`
    echo ${xmsJvm}
  else
    echo ${jvmParam}
  fi

}



function __MovePubLib() {
    if [[ -d ${installPath}/pub_libs ]];then
      if [[ -d  ${installPath}/pub_libs_bak_$(date '+%Y%m%d') ]];then
        rm -rf  ${installPath}/pub_libs_bak_$(date '+%Y%m%d')
      fi
      mv  ${installPath}/pub_libs ${installPath}/pub_libs_bak_$(date '+%Y%m%d')
    fi
    __CreateDir ${installPath}/pub_libs
    \cp -fr ${workdir}/jar/pub_libs/* ${installPath}/pub_libs
    if [[ -f  ${installPath}/pub_libs/repository/com/enmo/dbaas/dbaas-zcloud-feign/6.6.0-SNAPSHOT/_remote.repositories ]];then
      rm -f ${installPath}/pub_libs/repository/com/enmo/dbaas/dbaas-zcloud-feign/6.6.0-SNAPSHOT/_remote.repositories
    fi
}

function __startFromKeeper() {
  serviceName=$1
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
  prefixOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n prefix:|head -n 1|awk -F':' '{print $1}'`
  suffixOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
  enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`

  prefix=''
  for line in `sed -n "$[${serviceNameLine}+${prefixOffset}],$[${serviceNameLine}+${suffixOffset}-1]p" ${keeperConf}`
  do
    if [[ ${line} =~ "prefix:" ]];then
      line=`echo ${line}|sed "s/'//g"`
      prefix=${prefix}" "`echo ${line} |awk -F': ' '{print $2}'`
    else
      line=`echo ${line}|sed "s/'//g"`
      prefix=${prefix}" "${line}
    fi
  done

  suffix=''
  for line in `sed -n "$[${serviceNameLine}+${suffixOffset}],$[${serviceNameLine}+${enableOffset}-1]p" ${keeperConf}`
  do
    if [[ ${line} =~ "suffix:" ]];then
      line=`echo ${line}|sed "s/'//g"`
      suffix=${suffix}" "`echo ${line} |awk -F': ' '{print $2}'`

    else
      line=`echo ${line}|sed "s/'//g"`
      suffix=${suffix}" "${line}
    fi
  done
  a=${prefix}" "${suffix}
  info "$a"
  set +e
  sh -c "$a"
  set -e
}

function __stopOldService() {
  if [[ -f ${keeperBakPath} ]];then
    for serviceName in dbaas-operate-db dbaas-monitor-dashboard dbaas-api-create-dg dbaas-configuration dbaas-oceanbase dbaas-backend-sql-server dbaas-backend-db2 dbaas-backend-damengdb dbaas-create-mongodb dbaas-create-postgres dbaas-create-redis dbaas-create-shardingsphere dbaas-lowcode-http-engine dbaas-backend-oceanbase
    do
      serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperBakPath}`
      if [[ ${serviceNameLine} != "" ]];then
        enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperBakPath} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
        path=`sed -n "$[${serviceNameLine}],$[${serviceNameLine}+${enableOffset}-1]p" ${keeperBakPath}|grep "path:"|awk -F':' '{print $2}'`
        if [[ `ps -ef|grep ${path}|grep -v grep |wc -l` -gt 0  ]];then
          ps -ef |grep ${path}|grep -v grep | awk '{print $2}' | xargs kill -9
          info "${serviceName}停止成功"
        fi
      fi
    done
  fi
}

function __removeKeeperIfNotExist() {
  for serviceName in dbaas-wxwork-sender dbaas-sender-common dbaas-mail-sender dbaas-zabbix-sender ai-business zcloud-ai-adapter dbaas-backend-script dbaas-common-backupcenter dbaas-database-snapshot dbaas-ogg-management expert-knowledge-base influx
  do
    servicePath=${serviceName}
    if [[ ${serviceName} == "ai-business" || ${serviceName} == "zcloud-ai-adapter" ]];then
      servicePath=aicure/${serviceName}
    fi
    if [[ ${serviceName} == "influx" ]];then
      servicePath=soft/${serviceName}
    fi
    if [[ ! -e ${installPath}/${servicePath} ]];then
      __RemoveServiceFromKeeper ${serviceName} ${configPath}/keeper.yaml
    fi
  done
}


function __InstallNormalZcloudService() {
  find_result=$(find ./jar -type f -iname "${serviceName}*.jar" -print -quit)
  if [[ -n "$find_result" ]]; then
    h2 "[安装服务 ... ${serviceName}";
      startTime=$(date +"%s%N")
      cd ${workdir}
        versionPath=${logPath}/${version}
        if [[ ! -d ${versionPath} ]];then
          mkdir -p ${versionPath}
        fi
      info ""
      info "Start App [${serviceName}]  ..."
      __InstallService "${serviceName}"
      echo "${serviceName}" >> ${installPath}/serviceTemp

      if [[ -e ${installPath}/dbaas-apigateway ]];then
        cd ${installPath}/dbaas-apigateway
        ./start.sh
      fi
      endTime=$(date +"%s%N")
      echo "安装服务${serviceName}完成，耗时$( __CalcDuration ${startTime} ${endTime})"
  fi
}

function __InstallFlyway() {
  find_result=$(find ./jar -type f -iname "${serviceName}*.jar" -print -quit)
  if [[ -n "$find_result" ]]; then
    h2 "[安装服务 ... dbaas-flyway-manage";
    startTime=$(date +"%s%N")
    echo "Start App [${serviceName}]  ..."
    if [[ ${installType} == 4 ]];then
      if [[  ${serviceName} == "dbaas-flyway-manage" && $( __readINI nodeconfig/current.cfg service ${app} ) == ${nodeNum} ]];then
          if [[ ${databaseType} == "MySQL" ]];then
            mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "delete from monitormanager.monitormanager_flyway_schema_history where version ='23.06.20.1010554.1';"
            mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "delete from monitormanager.monitormanager_flyway_schema_history where version ='23.07.17.1010554.2';"
            if [[ ${theme} != 'zData' ]];then
              mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "UPDATE expert_knwl_base.expert_knwl_base_flyway_schema_history SET checksum=-1052896583 WHERE  version='22.04.08.03' and checksum=1143926634;;"
            fi
          else
            ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from monitormanager.mogdb_monitormanager_flyway_schema_history where version ='23.06.20.1010554.1';"
            ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from monitormanager.mogdb_monitormanager_flyway_schema_history where version ='23.07.17.1010554.2';"
          fi
      fi
    fi

    __InstallService "${serviceName}"
    echo "等待flyway写入，sleep 120"
    sleep 120

    echo "${serviceName}" >> ${installPath}/serviceTemp
    if [[  $( __readINI nodeconfig/current.cfg service dbaas-web ) == ${nodeNum} ]]; then
      echo "等待服务的启动，sleep 120"
      sleep 120
    fi
    echo "安装服务 dbaas-flyway-manage 完成，耗时$( __CalcDuration ${startTime} ${endTime})"
  fi
}


function __InstallZdbmonMgr() {
  find_result=$(find ./jar -type f -iname "${serviceName}*.jar" -print -quit)
  if [[ -n "$find_result" ]]; then
    startTime=$(date +"%s%N")
    echo "${serviceName}" >> ${installPath}/serviceTemp
    if [[ ${serviceName} == "zdbmon-mgr" && $( __readINI nodeconfig/current.cfg service ${app} ) == ${nodeNum} ]];then
      # ip，port 修改账号和密码
      if [[ ${databaseType} == "MySQL" ]];then
        mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "UPDATE zdbmon_config.t_data_node
  SET node_ip='${server_ip}', port=${server_port}, username='root', password='${dbaas_paasword_encode}', \`schema\`='zdbmon'
  WHERE id=1000;
  "
      else
        ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "UPDATE zdbmon_config.t_data_node
  SET node_ip='${server_ip}', port=${server_port}, username='${dbaas_username}', password='${dbaas_paasword_encode}', \"schema\"='zdbmon'
  WHERE id=1000;
  "
      fi
      if [[ -f ${configPath}/consultoken.txt ]];then
        consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
        export CONSUL_HTTP_TOKEN=${consulToken}
        info "consulToken=${CONSUL_HTTP_TOKEN}"
      fi
      # 更新hub的consul
      if [[ -f ${installPath}/soft/consul/consul/consul ]];then
        ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-registrationhub/zdbmon.host ${realHostIp}
      else
        consulIp=$( __readINI zcloud.cfg multiple consul.host )
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-registrationhub/zdbmon.host?dc=dc1
      fi
       # 升级更新历史表结构
      if [[ ${installType} == 4 && ${oldVersion1} < "6.0.1" ]];then
        if [[ ${databaseType} == "MySQL" ]];then
          mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  <  ${workdir}/zdbmon_sql/6.0.1_for_mysql.sql
          mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  <  ${workdir}/zdbmon_sql/6.0.1_for_mysql_1.sql
        else
          ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -f ${workdir}/zdbmon_sql/6.0.1_for_mogdb.sql
        fi
      fi
      if [[ ${installType} == 4 && ${oldVersion1} < "6.1.0" ]];then
        if [[ ${databaseType} == "MySQL" ]];then
           mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  <  ${workdir}/zdbmon_sql/6.1.0_for_mysql_session_detail.sql
           mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  <  ${workdir}/zdbmon_sql/6.1.0_for_mysql_sql_stat.sql
           mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  <  ${workdir}/zdbmon_sql/6.1.0_for_mysql_sql_text.sql
        else
          ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -f ${workdir}/zdbmon_sql/6.1.0_for_mogdb.sql
        fi
      fi
      if [[ ${installType} == 4 && ${oldVersion1} < "6.2.1" ]];then
        if [[ ${databaseType} == "MySQL" ]];then
           mysql -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  <  ${workdir}/zdbmon_sql/6.2.1_for_mysql_session_detail.sql
        else
          ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -f ${workdir}/zdbmon_sql/6.2.1_for_mogdb.sql
        fi
      fi
    fi
    __InstallService "${serviceName}"
    endTime=$(date +"%s%N")
    echo "安装服务 zdbmon-mgr 完成,耗时$( __CalcDuration ${startTime} ${endTime})"
  fi
}



function __CheckZcloudSingleServiceStatus()  {
  if [[ -d ${installPath}/dbaas-apigateway && ${serviceName} == "dbaas-apigateway"  ]];then
    su - zcloud -c"cd ${installPath};./start.sh --name dbaas-apigateway"
  fi
  if [[ -d ${installPath}/magic_cube && ${serviceName} == "magic-cube"  ]];then
    su - zcloud -c"cd ${installPath};./start.sh --name magic-cube"
  fi
  if [[ -d ${installPath}/ansible_executor && ${serviceName} == "ansible_executor" ]];then
    su - zcloud -c"cd ${installPath};./start.sh --name ansible_executor"
  fi
  info "Loop check three times"
  for loop in 1 2 3
  do
    info "start num ${loop} check"
    info "Wait 2 minutes for the service to start"
      #睡眠2分钟
    sleep 120s
  if [[ ${installNodeType} == "OneNode" ]]; then
    eurekaIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
  else
    eurekaIp=$( __readINI zcloud.cfg multiple web.ip )
  fi

    result=`curl -u admin:admin123 http://${eurekaIp}:8761/eureka/apps`
    if [[ "${result}" == "" ]] ;then
        echo "连接eureka异常，请检查eureka节点防火墙是否关闭"
    else
      upapps=$(echo ${result}|awk -F'[<>]' '{for(i=1;i<=NF;i++){
      if($i=="app"){appname=$(i+1)};
      if($i=="status" && $(i+1)=="UP"){print appname}
      }}')
      downApp=0
      for app  in  `ls ${installPath}  | egrep -v 'agent|zdbmon-mgr|keeper|zcloud-zoramon-mgr|aicure|dbaas-eureka-server|prometheus|alertmanager|slowmon_mgr|smart_baseline|dbaas-mail-sender|dbaas-registrationHub|soft|readme|start.sh|stop.sh|packages|version.txt|installparam.txt|serviceTemp|ansible_executor|DBaas-Lowcode-WorkFlow|open_workflow|magic_cube|zcloud_release.txt|dbType.txt|pub_libs|dbaas-wxwork-sender|dbaas-sender-common|dbaas-zabbix-sender|podman|magic-script-executor|logPath_IS_UNDEFINED|node-exporter|dbaas-operate-db|dbaas-monitor-dashboard|dbaas-api-create-dg|dbaas-configuration|dbaas-oceanbase|dbaas-backend-sql-server|dbaas-backend-db2|dbaas-backend-damengdb|dbaas-create-mongodb|dbaas-create-postgres|dbaas-create-redis|dbaas-create-shardingsphere|dbaas-lowcode-http-engine'`; do
        if [[ ${serviceName} == $app ]]; then
          if [[ $app == "expert-knowledge-base" ]];then
            app="expert-knwl-base"
          fi
          cnt=$(echo "$upapps"|grep -i $app|wc -l)
          if [[ $cnt -eq 0 ]]; then
            info "app not start:$app"; downApp=`expr $downApp + 1`;
          fi
          break
        fi
      done

      if [ ${downApp} == 0 ];then
        break
      fi
    fi

  done
}