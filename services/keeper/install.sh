installNodeType=#{installNodeType}
workdir=#{workdir}
homePath=#{homePath}
installPath=#{installPath}
logPath=#{logPath}
configPath=#{configPath}
installType=#{installType}
databaseType=#{databaseType}
release=#{release}
oldRelease=#{oldRelease}
javaIoTempDir=#{javaIoTempDir}
bakPath=#{bakPath}
hostIp=#{hostIp}
consulHost=#{consulHost}
dependenceOutsideMySQL=#{dependenceOutsideMySQL}
dependenceOutsidePrometheus=#{dependenceOutsidePrometheus}
bakTime=




nodeNum=#{nodeNum}

function __AddServiceToKeeper() {
    serviceName=$1
    echo " add service ${serviceName} to keeper"
    keeperConf=$2
    serviceNameLineCurrent=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
    if [[ ${serviceNameLineCurrent} == "" ]];then
      serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}/conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}/conf/keeper.yaml>temp.yaml
      endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
      sed -i "${endLine}r temp.yaml" ${keeperConf}
      rm -f temp.yaml

      if [[ -f ${homePath}/dbaas/zcloud-config/consultoken.txt ]];then
        consulToken=`less ${homePath}/dbaas/zcloud-config/consultoken.txt | grep SecretID|awk '{print $2}'`
        sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
      fi

      sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
      sed -i "s|#localIP#|${consulHost}|g" ${keeperConf}
      sed -i "s|#logPath#|${logPath}|g" ${keeperConf}

      echo " add service ${serviceName} to keeper success"
    fi
}

function __RemoveServiceFromKeeper() {
  serviceName=$1
  echo " remove service ${serviceName} from keeper"
  keeperConf=$2
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
  offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
  pathOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n path:|head -n 1|awk -F':' '{print $1}'`

  servicePath=`sed -n "$[${serviceNameLine}+${pathOffset}]p" ${keeperConf}|awk '{print $2}'`
  if [[ ${serviceNameLine} != "" ]];then
    sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}

    echo "old service ${serviceName} path ${servicePath}"
    serviceNum=`ps -ef | grep "${servicePath}" |grep -v grep |wc -l`
    echo "old service count num ${serviceNum}"
    if [[ ${serviceNum} != 0 ]]; then
        ps -ef | grep "${servicePath}" | grep -v grep | awk '{print $2}' | xargs kill -9
    fi

  fi
  echo " remove service ${serviceName} from keeper success"
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

  keeperConf=${configPath}/keeper.yaml
  sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
  sed -i "s|#localIP#|${consulHost}|g" ${keeperConf}
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
  echo "初始化配置成功"

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
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service ${service} ) ]] || [[  ${dependenceOutsideMySQL} = 1 ]]; then
              __RemoveServiceFromKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == dbaas-registrationHub ]] || [[ ${service} == prometheus ]] || [[ ${service} == alertmanager ]];then
           if [[ ${nodeNum} != $( __readINI nodeconfig/current.cfg service ${service} ) ]] || [[  ${dependenceOutsidePrometheus} = 1 ]]; then
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
             if [[  ${dependenceOutsideMySQL} = 1 ]]; then
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
           if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service ${service} ) && ${grepContent} == "0"  && ${dependenceOutsideMySQL} = 0 ]]; then
              __AddServiceToKeeper ${service} ${configPath}/keeper.yaml
           fi
        elif [[ ${service} == dbaas-registrationHub ]] || [[ ${service} == prometheus ]] || [[ ${service} == alertmanager ]];then
           grepContent=`cat ${configPath}/keeper.yaml | grep "\- serviceName: ${service}" | wc -l `
           if [[ ${nodeNum} == $( __readINI nodeconfig/current.cfg service ${service} ) && ${grepContent} == "0"  && ${dependenceOutsidePrometheus} = 0 ]]; then
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
      echo "cp -r  ${workdir}jar/keeper/ ${installPath}"
      cp -r ${workdir}jar/keeper/ ${installPath}
      FILE_PATH=${installPath}/keeper/
      mkdir -p ${installPath}/keeper/script
      PID=$(ps -ef | grep 'zcloud-keeper-' | grep -v grep | awk '{print $2}')
      if [[ ! -z $PID ]]; then
          echo 'Try to close old server id: '${PID}
      fi
      [[ ! -z $PID ]] && kill -9 ${PID}
      echo "$FILE_PATH"
      echo "$FILE_PATH"
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
  echo "keeper自动拉起任务已开启"
  cd ${workdir}
  cp script/keeper/stop.sh ${installPath}/keeper
  cp script/keeper/start.sh ${installPath}/keeper
  endLine=` sed -n '$='  ${installPath}/readme`
  sed -i "6,${endLine}d" ${installPath}/readme
  echo "`cat ${configPath}/keeper.yaml |grep  "\- serviceName: "| awk '{print $3}'`">>${installPath}/readme
  if [[ -f ${configPath}/keeper.xml ]];then
    mv ${configPath}/keeper.xml ${bakPath}
  fi
  echo "keeper安装完成"
}


__InitKeeperConfig

#__StartKeepService