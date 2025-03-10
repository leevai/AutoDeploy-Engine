#!/bin/bash

installNodeType=$( __readINI zcloud.cfg installtype install.node.type )
nodeNum=$( __ReadValue nodeconfig/installparam.txt nodeNum)

function __AddServiceToKeeper() {
    serviceName=$1
    info " add service ${serviceName} to keeper"
    keeperConf=$2
    serviceNameLineCurrent=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
    if [[ ${serviceNameLineCurrent} == "" ]];then
      serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}/conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}/conf/keeper.yaml>temp.yaml
      endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
      sed -i "${endLine}r temp.yaml" ${keeperConf}
      rm -f temp.yaml

      if [[ ${installNodeType} == "OneNode" ]]; then
        hostIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
      else
        hostIp=$( __readINI zcloud.cfg multiple consul.host )
      fi
      if [[ -f ${homePath}/dbaas/zcloud-config/consultoken.txt ]];then
        consulToken=`less ${homePath}/dbaas/zcloud-config/consultoken.txt | grep SecretID|awk '{print $2}'`
        sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
      fi

      sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
      sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
      sed -i "s|#logPath#|${logPath}|g" ${keeperConf}

      info " add service ${serviceName} to keeper success"
    fi
}

function __RemoveServiceFromKeeper() {
  serviceName=$1
  info " remove service ${serviceName} from keeper"
  keeperConf=$2
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
  offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
  pathOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n path:|head -n 1|awk -F':' '{print $1}'`

  servicePath=`sed -n "$[${serviceNameLine}+${pathOffset}]p" ${keeperConf}|awk '{print $2}'`
  if [[ ${serviceNameLine} != "" ]];then
    sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}

    info "old service ${serviceName} path ${servicePath}"
    serviceNum=`ps -ef | grep "${servicePath}" |grep -v grep |wc -l`
    info "old service count num ${serviceNum}"
    if [[ ${serviceNum} != 0 ]]; then
        ps -ef | grep "${servicePath}" | grep -v grep | awk '{print $2}' | xargs kill -9
    fi

  fi
  info " remove service ${serviceName} from keeper success"
}
function __InitKeeperConfig {
  \cp -f ${workdir}/script/global/readme ${installPath}
  \cp -f ${workdir}/script/global/start.sh ${installPath}
  \cp -f ${workdir}/script/global/stop.sh ${installPath}
  \cp -rf ${workdir}/script/jvm_param/ ${configPath}
  keeperBakPath=${configPath}/keeper.yaml.bak.${bakTime}
  if [[ ${installType} == 4 && -f  ${configPath}/keeper.yaml && ! -f ${keeperBakPath} ]];then
    mv -f ${configPath}/keeper.yaml ${keeperBakPath}
  fi
  if [[ ! -f ${configPath}/keeper.yaml ]];then
    cp conf/keeper.yaml ${configPath}
  fi

  if [[ ${installNodeType} == "OneNode" || ${nodeNum} == 1  ]]; then
    hostIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
  else
    hostIp=$( __readINI zcloud.cfg multiple consul.host )
  fi
  keeperConf=${configPath}/keeper.yaml
  sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
  sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
  sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
  if [[ -f ${homePath}/dbaas/zcloud-config/consultoken.txt ]];then
    consulToken=`less ${homePath}/dbaas/zcloud-config/consultoken.txt | grep SecretID|awk '{print $2}'`
    sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
  fi
  if [[ ${databaseType} == "MogDB" ]];then
    serviceNameLine=`sed -n "/serviceName: mysql\$/=" ${keeperConf}`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    if [[ ${serviceNameLine} != "" ]];then
      sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
    fi
  else
    serviceNameLine=`sed -n "/serviceName: mogdb\$/=" ${keeperConf}`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    if [[ ${serviceNameLine} != "" ]];then
      sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
    fi
  fi
  sed -ri "s|globalEnable: .*|globalEnable: false|g"  ${keeperConf}
  sed -i "s/    defaultProcessNum:/  defaultProcessNum:/g"  ${keeperConf}
  sed -i "s/    enable:/  enable:/g" ${keeperConf}
  sed -i "s/    suffix:/  suffix:/g"  ${keeperConf}
  sed -i "s/    prefix:/  prefix:/g"  ${keeperConf}
  sed -i "s/    path/  path/g"  ${keeperConf}
  sed -i "s/  - serviceName:/- serviceName:/g"  ${keeperConf}
  sed -ri "s|globalEnable: .*|globalEnable: false|g"  ${keeperConf}
  info "初始化配置成功"


#  if [[ ${installType} != 4 || ! -f  ${configPath}/keeper.yaml ]];then
#    cd ${workdir}
#    keeperConf=${configPath}/keeper.yaml
#
#
#    if [[ ! -f  ${configPath}/keeper.yaml ]];then
#      cp conf/keeper.yaml ${configPath}
#      if [[ ${installNodeType} == "OneNode" || ${nodeNum} == 1  ]]; then
#          hostIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
#      else
#          hostIp=$( __readINI zcloud.cfg multiple consul.host )
#      fi
#      sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
#      sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
#      sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
#      if [[ ${databaseType} == "MogDB" ]];then
#        serviceNameLine=`sed -n "/serviceName: mysql\$/=" ${keeperConf}`
#        offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
#        if [[ ${serviceNameLine} != "" ]];then
#          sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
#        fi
#      else
#        serviceNameLine=`sed -n "/serviceName: mogdb\$/=" ${keeperConf}`
#        offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
#        if [[ ${serviceNameLine} != "" ]];then
#          sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
#        fi
#      fi
#    fi
#    sed -ri "s|globalEnable: .*|globalEnable: false|g"  ${keeperConf}
#    sed -i "s/    defaultProcessNum:/  defaultProcessNum:/g"  ${keeperConf}
#    sed -i "s/    enable:/  enable:/g" ${keeperConf}
#    sed -i "s/    suffix:/  suffix:/g"  ${keeperConf}
#    sed -i "s/    prefix:/  prefix:/g"  ${keeperConf}
#    sed -i "s/    path/  path/g"  ${keeperConf}
#    sed -i "s/  - serviceName:/- serviceName:/g"  ${keeperConf}
#
#    if [[  -f  ${configPath}/keeper.xml ]];then
#      sed -ri "s|<globalEnable>.*</globalEnable>|<globalEnable>false</globalEnable>|g"  ${configPath}/keeper.xml
#    fi
#    info "初始化配置成功"
#  else
#    keeperConf=${configPath}/keeper.yaml
#    for lineNum in `cat -n ${keeperConf}|grep '\.jar'|grep -v agent|grep -v path|grep -v mail|awk -F' ' '{print $1}'`
#    do
#      if [[ `sed -n "${lineNum}p;$[${lineNum}+1]p" ${keeperConf} |grep '\-\-thin.root=' |wc -l` == 0 ]];then
#        sed -ri "${lineNum},$[${lineNum}+1]s|\.jar|.jar --thin.root=${installPath}/pub_libs|g" ${keeperConf}
#
#      fi
#      # 使用离线启动 升级 含有thin.root的才添加
#      if [[ `sed -n "${lineNum}p;$[${lineNum}+1]p" ${keeperConf} |grep '\-\-thin.offline=true' |wc -l` == 0 ]] && [[ `sed -n "${lineNum}p;$[${lineNum}+1]p" ${keeperConf} |grep '\-\-thin.root=' |wc -l` > 0 ]];then
#              sed -ri "${lineNum},$[${lineNum}+1]s|\.jar|.jar --thin.offline=true|g" ${keeperConf}
#      fi
#    done
#    sed -i "s/jdk1.8.0_171/jdk-17.0.11+9/g"  ${keeperConf}
#
#    # 去掉open_workflow和magic_cube path中多餘的部分
#    open_workflow_path_line=`cat -n ${keeperConf}|grep 'open_workflow'|grep path|awk -F' ' '{print $1}'`
#    magic_cube_path_line=`cat -n ${keeperConf}|grep 'magic_cube'|grep path|awk -F' ' '{print $1}'`
#    sed -ri "${open_workflow_path_line}s|open_workflow[[:space:]]*--conf=|open_workflow|g" ${keeperConf}
#    sed -ri "${magic_cube_path_line}s|magic_cube[[:space:]]*--consul\.endpoint=|magic_cube|g" ${keeperConf}
#
#    sed -i "s/    defaultProcessNum:/  defaultProcessNum:/g"  ${keeperConf}
#    sed -i "s/    enable:/  enable:/g" ${keeperConf}
#    sed -i "s/    suffix:/  suffix:/g"  ${keeperConf}
#    sed -i "s/    prefix:/  prefix:/g"  ${keeperConf}
#    sed -i "s/    path/  path/g"  ${keeperConf}
#    sed -i "s/  - serviceName:/- serviceName:/g"  ${keeperConf}
#    sed -ri "s|globalEnable: .*|globalEnable: false|g"  ${keeperConf}
#    info "keeper自动拉起任务已关闭"
#  fi

  #去除keeper中该节点不用配置的
  if [[ ${installNodeType} == "TwoNodes" ]] || [[ ${installNodeType} == "FourNodes" ]]; then
      echo "check need remove serviceName"
      for service in `cat ${configPath}/keeper.yaml |grep  "\- serviceName: "| awk '{print $3}'`;
      do
        #单独处理ai-business和zcloud-ai-adapter
        if [[ ${service} == ai-business ]] || [[ ${service} == zcloud-ai-adapter ]]; then
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service aicure ) ]]; then
              __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == nginx ]];then
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service dbaas-web ) ]]; then
              __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == mysql ]] ;then
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service ${service} ) ]] || [[  $( __readINI zcloud.cfg multiple "dependence.outside.mysql" ) = 1 ]]; then
              __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == dbaas-registrationHub ]] || [[ ${service} == prometheus ]] || [[ ${service} == alertmanager ]];then
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service ${service} ) ]] || [[  $( __readINI zcloud.cfg multiple "dependence.outside.prometheus" ) = 1 ]]; then
              __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
           fi
        else
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service ${service} )  && `echo ${service}|grep "sender"|wc -l` == 0 ]]; then
              __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
           fi
        fi
      done
  fi

   #单节点配置 去除keeper中该节点不用配置的
  if [[ ${installNodeType} == "OneNode" ]]; then
      echo "check need remove serviceName"
      for service in `cat ${configPath}/keeper.yaml |grep  "\- serviceName: "| awk '{print $3}'`;
        do
          if  [[ ${service} == mysql ]] ;then
             if [[  $( __readINI zcloud.cfg single "dependence.outside.mysql" ) = 1 ]]; then
                __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
             fi
          fi
        done
  fi

  #添加keeper中该节点没有配置的
  if [[ ${installNodeType} == "TwoNodes" ]] || [[ ${installNodeType} == "FourNodes" ]]; then
      echo "check need add serviceName"
      for service in `cat ${workdir}/conf/keeper.yaml  |grep  "\- serviceName: "| awk '{print $3}'`;
      do
        echo "current check add service ${service}"
        #单独处理ai-business和zcloud-ai-adapter
        if [[ ${service} == ai-business ]] || [[ ${service} == zcloud-ai-adapter ]]; then

           grepContent=`cat ${configPath}/keeper.yaml | grep "\- serviceName: ${service}" | wc -l `
           if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service aicure ) && ${grepContent} == "0" ]]; then
              __AddServiceToKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == nginx ]];then
           grepContent=`cat ${configPath}/keeper.yaml | grep "\- serviceName: ${service}" | wc -l `
           if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service dbaas-web ) && ${grepContent} == "0"  ]]; then
              __AddServiceToKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == mysql ]] ;then
           grepContent=`cat ${configPath}/keeper.yaml | grep "\- serviceName: ${service}" | wc -l `
           if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service ${service} ) && ${grepContent} == "0"  && $( __readINI zcloud.cfg multiple "dependence.outside.mysql" ) = 0 ]]; then
              __AddServiceToKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == dbaas-registrationHub ]] || [[ ${service} == prometheus ]] || [[ ${service} == alertmanager ]];then
           grepContent=`cat ${configPath}/keeper.yaml | grep "\- serviceName: ${service}" | wc -l `
           if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service ${service} ) && ${grepContent} == "0"  && $( __readINI zcloud.cfg multiple "dependence.outside.prometheus" ) = 0 ]]; then
              __AddServiceToKeeper ${service} ${configPath}/keeper.yaml
           fi
        else
          grepContent=`cat ${configPath}/keeper.yaml | grep "\- serviceName: ${service}" | wc -l `
          #处理其他服务
          if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service ${service} ) && ${grepContent} == "0" ]]; then
                  __AddServiceToKeeper ${service} ${configPath}/keeper.yaml
          fi
        fi
        echo "配置${service}结束"
      done
  fi
  # 标准版处理
  if [[ ${release} == "standard" ]];then
    #__RemoveServiceFromKeeper "dbaas-create-shardingsphere" ${configPath}/keeper.yaml
    #__RemoveServiceFromKeeper "dbaas-api-create-dg" ${configPath}/keeper.yaml
#    __RemoveServiceFromKeeper "dbaas-database-snapshot" ${configPath}/keeper.yaml
    __RemoveServiceFromKeeper "dbaas-common-backupcenter" ${configPath}/keeper.yaml
#    __RemoveServiceFromKeeper "dbaas-lowcode-http-engine" ${configPath}/keeper.yaml
#    __RemoveServiceFromKeeper "dbaas-management-database" ${configPath}/keeper.yaml
#    __RemoveServiceFromKeeper "dbaas-management-host" ${configPath}/keeper.yaml
#    __RemoveServiceFromKeeper "dbaas-lowcode-atomic-ability" ${configPath}/keeper.yaml
    __RemoveServiceFromKeeper "ai-business" ${configPath}/keeper.yaml
    __RemoveServiceFromKeeper "zcloud-ai-adapter" ${configPath}/keeper.yaml
    __RemoveServiceFromKeeper "influx" ${configPath}/keeper.yaml
    #__RemoveServiceFromKeeper "ansible_executor" ${configPath}/keeper.yaml
    #__RemoveServiceFromKeeper "open_workflow" ${configPath}/keeper.yaml
    #__RemoveServiceFromKeeper "magic-cube" ${configPath}/keeper.yaml

  fi
  if [[ ${release} == "enterprise" && ${oldRelease} == "standard" ]];then
    #__AddServiceToKeeper "dbaas-create-shardingsphere" ${configPath}/keeper.yaml
    #__AddServiceToKeeper "dbaas-api-create-dg" ${configPath}/keeper.yaml
#    __AddServiceToKeeper "dbaas-database-snapshot" ${configPath}/keeper.yaml
    __AddServiceToKeeper "dbaas-common-backupcenter" ${configPath}/keeper.yaml
#    __AddServiceToKeeper "dbaas-lowcode-http-engine" ${configPath}/keeper.yaml
#    __AddServiceToKeeper "dbaas-management-database" ${configPath}/keeper.yaml
#    __AddServiceToKeeper "dbaas-management-host" ${configPath}/keeper.yaml
#    __AddServiceToKeeper "dbaas-lowcode-atomic-ability" ${configPath}/keeper.yaml
    __AddServiceToKeeper "ai-business" ${configPath}/keeper.yaml
    __AddServiceToKeeper "zcloud-ai-adapter" ${configPath}/keeper.yaml
    __AddServiceToKeeper "influx" ${configPath}/keeper.yaml
    #__AddServiceToKeeper "ansible_executor" ${configPath}/keeper.yaml
    #__AddServiceToKeeper "open_workflow" ${configPath}/keeper.yaml
    #__AddServiceToKeeper "magic-cube" ${configPath}/keeper.yaml
  fi

  echo "配置keeper文件结束"

}

function __StartKeepService(){
      localip=${hostIp}
      if [[ -d ${installPath}/keeper ]]; then
         rm -rf ${installPath}/keeper
      fi
      info "cp -r  ${workdir}jar/keeper/ ${installPath}"
      cp -r ${workdir}jar/keeper/ ${installPath}
      FILE_PATH=${installPath}/keeper/
      mkdir -p ${installPath}/keeper/script
      PID=$(ps -ef | grep 'zcloud-keeper-' | grep -v grep | awk '{print $2}')
      if [[ ! -z $PID ]]; then
          echo 'Try to close old server id: '${PID}
      fi
      [[ ! -z $PID ]] && kill -9 ${PID}
      info "$FILE_PATH"
      info "$FILE_PATH"
      FILE_JAR=$(ls $FILE_PATH| grep 'zcloud-keeper-.*jar$' | awk '{print $1}')
      if [[ -z $FILE_JAR ]]; then
          echo 'Can not find zcloud-keeper file!'
      else
          logdir=${logPath}
          #复制logback.xml
          cp ${workdir}conf/logback/logback-default.xml ${installPath}/keeper/config/
          sed -i 's#name="logHome" value=.*#name="logHome" value="'${logdir}/keeper'/"/>#g' ${installPath}/keeper/config/logback-default.xml
          mv ${installPath}/keeper/config/logback-default.xml ${installPath}/keeper/config/logback.xml
          cd ${installPath}
          nohup ${installPath}/soft/java/jdk-17.0.11+9/bin/java -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/zcloud_keeper_%p.log -Xms256m -Xmx512m -jar $FILE_PATH${FILE_JAR} --spring.profiles.active=dev --logging.config=${installPath}/keeper/config/logback.xml >/dev/null 2>&1 &
          cd ${workdir}
      fi

      echo "#!/bin/bash
PID=\$(ps -ef | grep 'zcloud-keeper-' | grep -v grep | awk '{print \$2}')
FILE_JAR=\$(ls ${installPath}/keeper/| grep 'zcloud-keeper-.*jar\$' | awk '{print \$1}')
#如果存在该文件并且没有进程
if [[ -z \$FILE_JAR ]]; then
    echo 'Can not find zcloud-keeper file!'
else
    if [[  -z \$PID ]]; then
    echo 'Ready to start '\${FILE_JAR}
    nohup ${installPath}/soft/java/jdk-17.0.11+9/bin/java -Djava.io.tmpdir=${homePath}/dbaas/zcloud-log/java-io-tmpdir -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/zcloud_keeper_%p.log -Xms256m -Xmx512m -jar ${installPath}/keeper/\${FILE_JAR} --spring.profiles.active=dev --logging.config=${installPath}/keeper/config/logback.xml  >/dev/null 2>&1 &
    echo 'nohup ${installPath}/soft/java/jdk-17.0.11+9/bin/java -Djava.io.tmpdir=${homePath}/dbaas/zcloud-log/java-io-tmpdir -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/zcloud_keeper_%p.log -Xms256m -Xmx512m -jar ${installPath}/keeper/\${FILE_JAR} --spring.profiles.active=dev --logging.config=${installPath}/keeper/config/logback.xml  >/dev/null 2>&1 &'
    else
      echo 'zcloud-keeper running!'
    fi
fi
" > ${installPath}/keeper/script/startkeeper.sh
chmod +x ${installPath}/keeper/script/startkeeper.sh
  __AndMySQLStartSh
  sed -ri "s|globalEnable: .*|globalEnable: true|g"  ${configPath}/keeper.yaml
  info "keeper自动拉起任务已开启"
  cd ${workdir}
  cp script/keeper/stop.sh ${installPath}/keeper
  cp script/keeper/start.sh ${installPath}/keeper
  endLine=` sed -n '$='  ${installPath}/readme`
  sed -i "6,${endLine}d" ${installPath}/readme
  echo "`cat ${configPath}/keeper.yaml |grep  "\- serviceName: "| awk '{print $3}'`">>${installPath}/readme
  if [[ -f ${configPath}/keeper.xml ]];then
    mv ${configPath}/keeper.xml ${bakPath}
  fi
  info "keeper安装完成"
}


__InitKeeperConfig

__StartKeepService