. ./script/lib/dir_auth.sh

function __Install_node_exporter {
  echo ""
  echo "开始安装node-exporter"
  keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
  if [[ $(ps -ef|grep ${installPath}/node-exporter/node_exporter|grep -v grep|wc -l) -gt 0 ]];then
    ps -ef|grep ${installPath}/node-exporter/node_exporter|grep -v grep| awk '{print $2}' | xargs kill -9
    sleep 2s
  fi
  if [[ -d ${installPath}/node-exporter/ ]];then
    rm -fr ${installPath}/node-exporter/
  fi
  __CreateDir "${installPath}/node-exporter/"
  __CreateDir "${installPath}/node-exporter/log"
  cp ${workdir}/soft/node-exporter/node_exporter ${installPath}/node-exporter/
  cd ${installPath}/node-exporter/
  nohup ${installPath}/node-exporter/node_exporter --collector.disable-defaults --web.disable-exporter-metrics --collector.cpu --collector.meminfo --collector.uname --collector.stat --collector.os --collector.textfile --web.listen-address=:8092 &>>${installPath}/node-exporter/log/node_exporter.log &
  serviceName=node-exporter
  serviceNameLine=`sed -n "/serviceName: node-exporter\$/=" ${keeperConf}`
  offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
  if [[ ${serviceNameLine} == "" ]];then
    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}/conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    if [[ ${serviceNameLine} != "" ]];then
      sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}/conf/keeper.yaml>temp.yaml
      endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
      sed -i "${endLine}r temp.yaml" ${keeperConf}
      rm -f temp.yaml
      sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
    fi
  fi
  ## 如果启动了agent，关闭agent
  serviceNameLine=`sed -n "/serviceName: agent\$/=" ${keeperConf}`
  if [[ ${serviceNameLine} != "" ]];then
    cd ${installPath}
    ./stop.sh --name agent
  fi

  cd ${workdir}
  cp script/other/start.sh ${installPath}/node-exporter
  cp script/other/stop.sh ${installPath}/node-exporter
  echo "node-exporter安装完成"
}

function __InstallAgent {
     #切换到agent目录
     echo ""
     echo "开始安装agent"
     cd ${workdir}/jar/agent
     __CreateDir "${installPath}/agent/"
     keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
     if [[ $(ps -ef|grep agentServer|grep root|grep -v grep|wc -l) -gt 0 ]];then
       echo "root用户已安装agent，无需重复安装"
       serviceNameLine=`sed -n "/serviceName: agent\$/=" ${keeperConf}`
       enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
       lineNum=$[ ${serviceNameLine} + ${enableOffset} ]
       sed -ri "${lineNum}s|enable: .*|enable: false|g" ${keeperConf}
     else
      if [[ $(ps -ef|grep agentServer|grep -v grep|wc -l) -gt 0 ]];then
         ps -ef |grep agentServer|grep -v grep | awk '{print $2}' | xargs kill -9
         sleep 2s
       fi
       port=$(__CheckPort agentServer)
       if [[ ${port} -gt 0 ]];then
         error "${port}端口已被占用，agentServer安装失败,安装中断"
         exit 1
       fi
       #判断是否已解压
       if [[ -d ${installPath}/agent/agent ]]; then
           rm -rf ${installPath}/agent/agent
       fi
       tar -xf agent_linux_*.tar -C "${installPath}/agent/"
       #执行脚本
       sed -i "s|<root level=\"WARN\">|<root level=\"INFO\">|g" ${installPath}/agent/agent/agent/lib/logback.xml
       sed -i "s|#logHome#|${installPath}/agent/agent/log|g" ${installPath}/agent/agent/agent/lib/logback.xml
       echo "nohup ${installPath}/soft/java/jdk-17.0.11+9/bin/java -jar -Xms256m -Xmx512m -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/agentServer_%p.log -Dlogback.configurationFile=${installPath}/agent/agent/agent/lib/logback.xml ${installPath}/agent/agent/agent/lib/agentServer.jar -Dport=8100 -dagentServer >/dev/null 2>&1 &"
       nohup ${installPath}/soft/java/jdk-17.0.11+9/bin/java -jar -Xms256m -Xmx512m -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/agentServer_%p.log -Dlogback.configurationFile=${installPath}/agent/agent/agent/lib/logback.xml ${installPath}/agent/agent/agent/lib/agentServer.jar -Dport=8100 -dagentServer >/dev/null 2>&1 &
       cd ${workdir}
       cp script/other/start.sh ${installPath}/agent/agent/agent/lib
       cp script/other/stop.sh ${installPath}/agent/agent/agent/lib
       echo "agent 安装成功"
     fi

}
#安装监控中心alertmanager
function __InstallAlertmanager {
     echo ""
     echo "开始安装alertmanager"
     #切换到Alertmanager
     cd jar
     if [[ $(ps -ef|grep soft-install/alertmanager/alertmanager|grep -v grep|wc -l) -gt 0 ]];then
       ps -ef |grep soft-install/alertmanager/alertmanager|grep -v grep | awk '{print $2}' | xargs kill -9
       sleep 5s
     fi

     port=$(__CheckPort zcloud_altermanager)
     if [[ ${port} -gt 0 ]];then
       error "${port}端口已被占用，altermanager安装失败,安装中断"
       exit 1
     fi
     #判断是否已解压
     if [[ -d ${installPath}/alertmanager ]]; then
         rm -rf ${installPath}/alertmanager
     fi
     if [[ ! -e ${installPath}/alertmanager/log/ ]];then
      __CreateDir "${installPath}/alertmanager/log/"
     fi
     #解压
     tar -xf alertmanager.tar.gz -C "${installPath}"
     #进入目录,执行脚本
     cd ${installPath}/alertmanager
     if [[ -f  ${configPath}/keeper.xml ]];then
        serviceNameLine=`sed -n "/<serviceName>alertmanager<\/serviceName>/=" ${configPath}/keeper.xml`
        prefix=`sed -n $[${serviceNameLine}+2]p ${configPath}/keeper.xml |awk -F'>' '{print $2}'|awk -F'<' '{print $1}'`
        prefix=`echo ${prefix//&gt;/>}`
        prefix=`echo ${prefix//&amp;/&}`
        suffix=`sed -n $[${serviceNameLine}+3]p ${configPath}/keeper.xml |awk -F'>' '{print $2}'|awk -F'<' '{print $1}'`
        suffix=`echo ${suffix//&gt;/>}`
        suffix=`echo ${suffix//&amp;/&}`
        newLine=`sed -n "/serviceName: alertmanager\$/=" ${configPath}/keeper.yaml`
        prefixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n prefix:|head -n 1|awk -F':' '{print $1}'`
        suffixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
        #content=`$[$newLine+$prefixOffset],$[$newLine+$suffixOffset-1]p ${configPath}/keeper.yaml`
        sed -i "$[$newLine+$prefixOffset],$[$newLine+$suffixOffset-1]d" ${configPath}/keeper.yaml
        echo "  prefix: '${prefix}'" >temp.yaml
        sed -i "$[$newLine+$prefixOffset-1]r temp.yaml"  ${configPath}/keeper.yaml

        suffixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
        enableOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n enable:|head -n 1|awk -F':' '{print $1}'`

        #content=`$[$newLine+$suffixOffset],$[$newLine+$enableOffset-1]p ${configPath}/keeper.yaml`
        sed -i "$[$newLine+$suffixOffset],$[$newLine+$enableOffset-1]d" ${configPath}/keeper.yaml
        echo "  suffix: ' ${suffix}'" >temp.yaml
        sed -i "$[$newLine+$suffixOffset-1]r temp.yaml"  ${configPath}/keeper.yaml
        rm -f temp.yaml
     fi
     #增加alertmanager认证
     if [[ ! -f ${installPath}/alertmanager/web.yml ]]; then
      echo "basic_auth_users:
  admin: \$2a\$12\$nDpHH3wLUuXVrPDPkHVjgeZqH0bIjuc1hcN1Z1JiNMmmQjHDriawa" >> ${installPath}/alertmanager/web.yml
     fi
     if [[ `cat  ${configPath}/keeper.yaml |grep "\-\-web.config.file=${installPath}/alertmanager/web.yml" | wc -l` == 0 ]];then
       echo "增加alertmanager 认证文件web.yml"
       sed -i "s|--web.listen-address=:8094|--web.listen-address=:8094 --web.config.file=${installPath}/alertmanager/web.yml|g" ${configPath}/keeper.yaml
     fi
     #echo "nohup ${installPath}/alertmanager/alertmanager --config.file=${installPath}/alertmanager/alertmanager.yml --web.listen-address=:8094 --web.config.file=${installPath}/alertmanager/web.yml --cluster.advertise-address=127.0.0.1:8094 --log.level=error &>>${installPath}/alertmanager/log/alertmanager.log &"
     #nohup ${installPath}/alertmanager/alertmanager --config.file=${installPath}/alertmanager/alertmanager.yml --web.listen-address=:8094 --web.config.file=${installPath}/alertmanager/web.yml --cluster.advertise-address=127.0.0.1:8094 --log.level=error &>>${installPath}/alertmanager/log/alertmanager.log &
     cd ${workdir}
     cp script/other/start.sh ${installPath}/alertmanager
     cp script/other/stop.sh ${installPath}/alertmanager
     echo "alertmanager安装完成"
}

#安装监控中心zoramon-mgr
function __InstallZcloud_zoramon_mgr {
     echo ""
     echo "开始安装 zoramon-mgr"
     #切换到zoramon-mgr
     cd jar
     if [[ $(ps -ef|grep zcloud-zoramon-mgr|grep -v grep|wc -l) -gt 0 ]];then
       ps -ef |grep zcloud-zoramon-mgr|grep -v grep | awk '{print $2}' | xargs kill -9
       sleep 2s
     fi
     port=$(__CheckPort zcloud_zoramon_mgr)
     if [[ ${port} -gt 0 ]];then
       error "${port}端口已被占用，zcloud_zoramon_mgr安装失败,安装中断"
       exit 1
     fi
     #判断是否已解压
     if [[ -d ${installPath}/zcloud-zoramon-mgr ]]; then
         rm -rf ${installPath}/zcloud-zoramon-mgr
     fi

     #解压
     tar -xf zcloud-zoramon-mgr.tar.gz -C "${installPath}"
     #修改配置文件
     cd ${workdir}
     __GenAppProper_zoramon_mgr
     chmod u+x ${installPath}/zcloud-zoramon-mgr/zoramon_mgr
     #进入目录,执行脚本
     #echo "nohup ${installPath}/zcloud-zoramon-mgr/zoramon_mgr --conf.zoramon=${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml  --conf.clean=${installPath}/zcloud-zoramon-mgr/conf/dataclean.yaml  --log.filename=${logPath}/log/zoramon_mgr.log >/dev/null 2>&1 &"
     #nohup ${installPath}/zcloud-zoramon-mgr/zoramon_mgr --conf.zoramon=${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml  --conf.clean=${installPath}/zcloud-zoramon-mgr/conf/dataclean.yaml  --log.filename=${logPath}/log/zoramon_mgr.log >/dev/null 2>&1 &
     if [[  -f  ${configPath}/keeper.xml ]];then
        serviceNameLine=`sed -n "/<serviceName>zoramon-mgr<\/serviceName>/=" ${configPath}/keeper.xml`
        prefix=`sed -n $[${serviceNameLine}+2]p ${configPath}/keeper.xml |awk -F'>' '{print $2}'|awk -F'<' '{print $1}'`
        prefix=`echo ${prefix//&gt;/>}`
        prefix=`echo ${prefix//&amp;/&}`
        suffix=`sed -n $[${serviceNameLine}+3]p ${configPath}/keeper.xml |awk -F'>' '{print $2}'|awk -F'<' '{print $1}'`
        suffix=`echo ${suffix//&gt;/>}`
        suffix=`echo ${suffix//&amp;/&}`
        newLine=`sed -n "/serviceName: zoramon-mgr\$/=" ${configPath}/keeper.yaml`
        prefixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n prefix:|head -n 1|awk -F':' '{print $1}'`
        suffixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
        #content=`$[$newLine+$prefixOffset],$[$newLine+$suffixOffset-1]p ${configPath}/keeper.yaml`
        sed -i "$[$newLine+$prefixOffset],$[$newLine+$suffixOffset-1]d" ${configPath}/keeper.yaml
        echo "  prefix: '${prefix}'" >temp.yaml
        sed -i "$[$newLine+$prefixOffset-1]r temp.yaml"  ${configPath}/keeper.yaml

        suffixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
        enableOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n enable:|head -n 1|awk -F':' '{print $1}'`

        #content=`$[$newLine+$suffixOffset],$[$newLine+$enableOffset-1]p ${configPath}/keeper.yaml`
        sed -i "$[$newLine+$suffixOffset],$[$newLine+$enableOffset-1]d" ${configPath}/keeper.yaml
        echo "  suffix: ' ${suffix}'" >temp.yaml
        sed -i "$[$newLine+$suffixOffset-1]r temp.yaml"  ${configPath}/keeper.yaml
        rm -f temp.yaml
    fi
     cd ${workdir}
     cp script/other/start.sh ${installPath}/zcloud-zoramon-mgr
     cp script/other/stop.sh ${installPath}/zcloud-zoramon-mgr
     echo "zoramon-mgr 安装完成"
}

#安装监控中心slowmon-mgr
function __InstallZcloud_slowmon_mgr {
    echo ""
     echo "开始安装slowmon-mgr "
     #slowmon-mgr
     cd jar
     if [[ $(ps -ef|grep slowmon_mgr|grep -v grep|wc -l) -gt 0 ]];then
       ps -ef |grep slowmon_mgr|grep -v grep | awk '{print $2}' | xargs kill -9
       sleep 2s
     fi
     port=$(__CheckPort zcloud_slowmon_mgr)
     if [[ ${port} -gt 0 ]];then
       error "${port}端口已被占用，zcloud_slowmon_mgr安装失败,安装中断"
       exit 1
     fi
     #判断是否已解压
     if [[ -d ${installPath}/slowmon_mgr ]]; then
         rm -rf ${installPath}/slowmon_mgr
     fi
     #解压
     tar -xf slowmon_mgr.tar.gz -C "${installPath}"
     #修改配置文件
     cd ${workdir}
     __GenAppProper_slowmon_mgr
     cd ${installPath}/slowmon_mgr
     #进入目录,执行脚本
     chmod u+x ${installPath}/slowmon_mgr/slowmon_mgr
     nohup ${installPath}/slowmon_mgr/slowmon_mgr --no-log.console >/dev/null 2>&1 &
     echo "slowmon启动命令：nohup ${installPath}/slowmon_mgr/slowmon_mgr --no-log.console >/dev/null 2>&1 &"
     cd ${workdir}
     cp script/other/start.sh ${installPath}/slowmon_mgr
     cp script/other/stop.sh ${installPath}/slowmon_mgr
     echo "slowmon_mgr 安装完成"
}

#安装监控中心dbaas-mail-sender
function __InstallDbaas_mail_sender {
    echo ""
    echo "开始安装 dbaas-mail-sender "
    cd ${workdir}/jar
    javapath="`echo $JAVA_HOME`/bin/java"
    if [[ ! -e ${installPath}/dbaas-mail-sender ]]; then
    #全新安装
      cp -r dbaas-mail-sender ${installPath}
      port=$(__CheckPort zcloud_mail_sender)
      if [[ ${port} -gt 0 ]];then
        error "${port}端口已被占用，zcloud_mail_sender安装失败,安装中断"
        exit 1
      fi
      mailJar=`ls ${installPath}/dbaas-mail-sender/dbaas-mail-sender*.jar`
      sed -ri "s|${installPath}/dbaas-mail-sender/dbaas-mail-sender.*\.jar|${mailJar}|g" ${configPath}/keeper.yaml
      __startFromKeeper dbaas-mail-sender
      if [[ ${theme} == "zData" ]];then
        echo "a24c36da7f1d436d82fabfa61e2795b2=a24c36da7f1d436d82fabfa61e2795b2" > ${installPath}/dbaas-mail-sender/accessKey.properties
      fi
      cd ${workdir}

    else
      cd ${workdir}/jar
      mailJar=`ls ${installPath}/dbaas-mail-sender/dbaas-mail-sender*.jar`
      nowVersion=$(ls dbaas-mail-sender/dbaas-mail-sender*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      oldVersion=$(ls ${installPath}/dbaas-mail-sender/dbaas-mail-sender*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      if [[ ${nowVersion} != ${oldVersion} ]]; then
        if [[ $(ps -ef|grep dbaas-mail-sender|grep -v grep|wc -l) -gt 0 ]];then
          ps -ef |grep dbaas-mail-sender|grep -v grep | awk '{print $2}' | xargs kill -9
          echo "关闭dbaas-mail-sender成功"
          sleep 2s
        fi
        port=$(__CheckPort zcloud_mail_sender)
        if [[ ${port} -gt 0 ]];then
          error "${port}端口已被占用，zcloud_mail_sender安装失败,安装中断"
          exit 1
        fi
        mv ${mailJar} "${mailJar}.bak"
        \cp -rf dbaas-mail-sender/ ${installPath}
        mailJar=`ls ${installPath}/dbaas-mail-sender/dbaas-mail-sender*.jar`
        sed -ri "s|${installPath}/dbaas-mail-sender/dbaas-mail-sender.*\.jar|${mailJar}|g" ${configPath}/keeper.yaml
        __startFromKeeper dbaas-mail-sender
      else
        if [[ $(ps -ef|grep dbaas-mail-sender|grep -v grep|wc -l) = 0 ]];then
          mailJar=`ls ${installPath}/dbaas-mail-sender/dbaas-mail-sender*.jar`
          sed -ri "s|${installPath}/dbaas-mail-sender/dbaas-mail-sender.*\.jar|${mailJar}|g" ${configPath}/keeper.yaml
          __startFromKeeper dbaas-mail-sender
        else
          echo "dbaas-mail-sender版本没有变化，且处于正常的运行状态，无需处理"
        fi
      fi
    fi
    echo "dbaas-mail-sender 安装完成"
    cd ${workdir}
    \cp -f script/start.sh ${installPath}/dbaas-mail-sender
    \cp -f script/stop.sh ${installPath}/dbaas-mail-sender
}

#安装监控中心${senderName}
function __Install_alert_sender {
    senderName=$1
    echo ""
    echo "开始安装 ${senderName} "
    cd ${workdir}/jar
    javapath="`echo $JAVA_HOME`/bin/java"
    if [[ ! -e ${installPath}/${senderName} ]]; then
    #全新安装
      cp -r ${senderName} ${installPath}
      port=$(__CheckPort ${senderName})
      if [[ ${port} -gt 0 ]];then
        error "${port}端口已被占用，${senderName}安装失败,安装中断"
        exit 1
      fi
      wxworkJar=`ls ${installPath}/${senderName}/${senderName}*.jar`
      sed -ri "s|${installPath}/${senderName}/${senderName}.*\.jar|${wxworkJar}|g" ${configPath}/keeper.yaml
      __startFromKeeper ${senderName}
      cd ${workdir}

    else
      cd ${workdir}/jar
      wxworkJar=`ls ${installPath}/${senderName}/${senderName}*.jar`
      nowVersion=$(ls ${senderName}/${senderName}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      oldVersion=$(ls ${installPath}/${senderName}/${senderName}*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      if [[ ${nowVersion} != ${oldVersion} ]]; then
        if [[ $(ps -ef|grep ${senderName}|grep -v grep|wc -l) -gt 0 ]];then
          ps -ef |grep ${senderName}|grep -v grep | awk '{print $2}' | xargs kill -9
          echo "关闭${senderName}成功"
          sleep 2s
        fi
        port=$(__CheckPort ${senderName})
        if [[ ${port} -gt 0 ]];then
          error "${port}端口已被占用，${senderName}安装失败,安装中断"
          exit 1
        fi
        mv ${wxworkJar} "${wxworkJar}.bak"
        \cp -rf ${senderName}/ ${installPath}
        wxworkJar=`ls ${installPath}/${senderName}/${senderName}*.jar`
        sed -ri "s|${installPath}/${senderName}/${senderName}.*\.jar|${wxworkJar}|g" ${configPath}/keeper.yaml
        __startFromKeeper ${senderName}
      else
        if [[ $(ps -ef|grep ${senderName}|grep -v grep|wc -l) = 0 ]];then
          wxworkJar=`ls ${installPath}/${senderName}/${senderName}*.jar`
          sed -ri "s|${installPath}/${senderName}/${senderName}.*\.jar|${wxworkJar}|g" ${configPath}/keeper.yaml
          __startFromKeeper ${senderName}
        else
          echo "${senderName}版本没有变化，且处于正常的运行状态，无需处理"
        fi
      fi
    fi
    keeperConf=${configPath}/keeper.yaml
    serviceNameLine=`sed -n "/serviceName: ${senderName}\$/=" ${keeperConf}`
    if [[ ${serviceNameLine} = "" ]];then
      serviceNameLine=`sed -n "/serviceName: ${senderName}\$/=" ${workdir}/conf/keeper.yaml`
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}/conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p"  ${workdir}/conf/keeper.yaml>temp.yaml
      endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
      sed -i "${endLine}r temp.yaml" ${keeperConf}
      rm -f temp.yaml
      sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
      sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
    else
      enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
      lineNum=$[ ${serviceNameLine} + ${offset} ]
      sed -ri "${lineNum}s|enable: .*|enable: true|g" ${keeperConf}
    fi
    sed -ri "s|${installPath}/${senderName}/${senderName}.*\.jar|${wxworkJar}|g" ${configPath}/keeper.yaml
    echo "${senderName} 安装完成"
    cd ${workdir}
    \cp -f script/start.sh ${installPath}/${senderName}
    \cp -f script/stop.sh ${installPath}/${senderName}
}

#安装监控中心dbaas-registrationHub
function __InstallDbaas_registrationHub {
    echo ""
    echo "开始安装dbaas-registrationHub"
    cd ${workdir}/jar
    keeperConf=${configPath}/keeper.yaml
    javapath="`echo $JAVA_HOME`/bin/java"
    cd ${workdir}
    if [[ ${installNodeType} == "OneNode" ]]; then
          consul_ip=$( __ReadValue ${workdir}/nodeconfig/installparam.txt hostIp)
    else
          consul_ip=$( __readINI ${workdir}/zcloud.cfg multiple consul.host )
    fi
    cd ${workdir}/jar
    consul_port="8500"

    if [[ -f ${configPath}/consultoken.txt ]]; then
    consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
    CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
    fi
    echo "dbaas-registrationHub" >> ${installPath}/serviceTemp
    if [[ ! -e ${installPath}/dbaas-registrationHub ]]; then
    #全新安装
      tar -xf dbaas-registrationHub.tar.gz -C "${installPath}"
      port=$(__CheckPort zcloud_registrationHub)
      if [[ ${port} -gt 0 ]];then
        error "${port}端口已被占用，zcloud_registrationHub安装失败,安装中断"
        exit 1
      fi
      cd ${workdir}
      jvmTemplate=($(__readINI zcloud.cfg common "jvm.template"))
      jvmParam=($(__readINI script/jvm_param/jvm_template.cfg ${jvmTemplate} "dbaas-registrationHub"))
      jvmMin=`echo ${jvmParam}|awk -F'/' '{print $1}'`
      jvmMax=`echo ${jvmParam}|awk -F'/' '{print $NF}'`
      if [[ `echo ${jvmMax} |egrep "^([1-9][0-9]*|-[1-9][0-9]*)$" |wc -l` = 0 || `echo ${jvmMin} |egrep "^([1-9][0-9]*|-[1-9][0-9]*)$"|wc -l` = 0 ]];then
        jvmMax=512
        jvmMin=256
      fi
      if [[ ${jvmMin} -gt ${jvmMax} ]];then
        echo "${jarName}配置参数为-Xms${jvmMin}m -Xmx${jvmMax}m, 最小值大于了最大值，使用默认jvm 参数-Xms256m -Xmx512m"
        jvmMax=512
        jvmMin=256
      fi
      runcmd="-Djava.io.tmpdir=${logPath}/java-io-tmpdir -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/dbaas-registrationHub_%p.log -Xms${jvmMin}m -Xmx${jvmMax}m -Duser.timezone=GMT+08"
      registrationHub=`ls ${installPath}/dbaas-registrationHub/dbaas-registrationHub*.jar`
      serviceNameLine=`sed -n "/serviceName: dbaas-registrationHub\$/=" ${configPath}/keeper.yaml`
      offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
      set +e
      xmsJvm=`echo ${runcmd} |egrep -o "\-Xms[0-9]*m"`
      xmxJvm=`echo ${runcmd} |egrep -o "\-Xmx[0-9]*m"`
      set -e
      sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xms[0-9]*m|${xmsJvm}|g" ${keeperConf}
      sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xmx[0-9]*m|${xmxJvm}|g" ${keeperConf}
      sed -ri "s|${installPath}/dbaas-registrationHub/dbaas-registrationHub.*\.jar|${registrationHub}|g" ${configPath}/keeper.yaml
      __startFromKeeper dbaas-registrationHub
    else
      ## 升级的时候先停了zdbmon-mgr,以免生成错误的表名
      cd ${workdir}/jar
      if [[ $(ps -ef|grep zdbmon-mgr|grep -v grep|wc -l) -gt 0 ]];then
        ps -ef |grep zdbmon-mgr|grep -v grep | awk '{print $2}' | xargs kill -9
        echo "关闭zdbmon-mgr成功"
      fi
      tar -xf dbaas-registrationHub.tar.gz
      jarName=$(ls ${installPath}/dbaas-registrationHub/dbaas-registrationHub*.jar )
      nowVersion=$(ls dbaas-registrationHub/dbaas-registrationHub*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      oldVersion=$(ls ${installPath}/dbaas-registrationHub/dbaas-registrationHub*.jar | awk -F'/' '{print $NF}' | awk -F'-' '{print $(NF-1)}')
      if [[ ${nowVersion} != ${oldVersion} ]]; then
        if [[ $(ps -ef|grep dbaas-registrationHub|grep -v grep|wc -l) -gt 0 ]];then
          set +e
          jvmParam=`ps -ef|grep dbaas-registrationHub|egrep -o "\-Xms[0-9]*m \-Xmx[0-9]*m"`
          set -e
          ps -ef |grep dbaas-registrationHub|grep -v grep | awk '{print $2}' | xargs kill -9
          echo "关闭dbaas-registrationHub成功"
          sleep 2s
        fi
        port=$(__CheckPort zcloud_registrationHub)
        if [[ ${port} -gt 0 ]];then
          error "${port}端口已被占用，zcloud_registrationHub安装失败,安装中断"
          exit 1
        fi
        mv ${jarName} "${jarName}.bak"
        \cp -rf dbaas-registrationHub/ ${installPath}
        registrationHub=`ls ${installPath}/dbaas-registrationHub/dbaas-registrationHub*.jar`
        serviceNameLine=`sed -n "/serviceName: dbaas-registrationHub\$/=" ${configPath}/keeper.yaml`
        offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
        xmsJvm=$(__queryJvmXms dbaas-registrationHub)
        xmxJvm=$(__queryJvmXmx dbaas-registrationHub)
        echo ${xmsJvm}
        echo ${xmxJvm}
        if [[ ${xmsJvm} != '' ]];then
          sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xms[0-9]*m|${xmsJvm}|g" ${keeperConf}
        fi
        if [[ ${xmxJvm} != '' ]];then
          sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xmx[0-9]*m|${xmxJvm}|g" ${keeperConf}
        fi
        sed -ri "s|${installPath}/dbaas-registrationHub/dbaas-registrationHub.*\.jar|${registrationHub}|g" ${configPath}/keeper.yaml
        __startFromKeeper dbaas-registrationHub

      else
        if [[ $(ps -ef|grep dbaas-registrationHub|grep -v grep|wc -l) = 0 ]];then
          registrationHub=`ls ${installPath}/dbaas-registrationHub/dbaas-registrationHub*.jar`
          serviceNameLine=`sed -n "/serviceName: dbaas-registrationHub\$/=" ${configPath}/keeper.yaml`
          offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
          xmsJvm=$(__queryJvmXms dbaas-registrationHub)
          xmxJvm=$(__queryJvmXmx dbaas-registrationHub)
          if [[ ${xmsJvm} != '' ]];then
            sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xms[0-9]*m|${xmsJvm}|g" ${keeperConf}
          fi
          if [[ ${xmxJvm} != '' ]];then
            sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xmx[0-9]*m|${xmxJvm}|g" ${keeperConf}
          fi
          sed -ri "s|${installPath}/dbaas-registrationHub/dbaas-registrationHub.*\.jar|${registrationHub}|g" ${configPath}/keeper.yaml
          __startFromKeeper dbaas-registrationHub
        else
          echo "registrationHub版本没有变化，且处于正常的运行状态，无需处理"
        fi
      fi
    fi
    \cp -f ${workdir}/script/start.sh ${installPath}/dbaas-registrationHub
    \cp -f ${workdir}/script/stop.sh ${installPath}/dbaas-registrationHub
    echo "dbaas-registrationHub 安装完成"
    cd ${workdir}
}
#安装监控中心prometheus
function __InstallPrometheus {
  zcloudCfg=${workdir}/zcloud.cfg
  if [[ ${installNodeType} == "OneNode" ]]; then
    outsidePrometheus=$(__readINI ${zcloudCfg} single dependence.outside.prometheus)
  else
    outsidePrometheus=$(__readINI ${zcloudCfg} multiple dependence.outside.prometheus)
  fi
  if [[  $( __readINI nodeconfig/current.cfg service prometheus ) == ${nodeNum}  && ${outsidePrometheus} = 0 ]]; then



    cd "${workdir}/jar"
    tar -xf prometheus.tar.gz
    __CreateDir "${installPath}/prometheus"
    if [[ ! -e ${installPath}/prometheus/log ]];then
      mkdir -p ${installPath}/prometheus/log
    fi
    if [[ ! -f ${installPath}/prometheus/prometheus ]]; then
      #解压prometheus
      tar -xf ${workdir}/jar/prometheus.tar.gz -C "${installPath}"
      if [[ -f /usr/lib/systemd/system/zcloud_prometheus.service ]];then
        dataDir=($( __ReadValue ${logPath}/evn.cfg prometheusDataDir))
        nohup ${installPath}/prometheus/prometheus --storage.tsdb.path=${dataDir} --config.file=${installPath}/prometheus/prometheus.yml --query.lookback-delta=15m --web.enable-lifecycle --web.listen-address=:8093 --web.config.file=${installPath}/prometheus/web.yml --log.level=error --web.enable-admin-api --enable-feature=promgl-at-modifier --storage.tsdb.retention.time=15y &>>${installPath}/prometheus/log/prometheus.log &
        serviceNameLine=`sed -n "/serviceName: prometheus\$/=" ${keeperConf}`
        offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
        enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
        sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s/--storage.tsdb.path=.* --/--storage.tsdb.path=${dataDir} --/g" ${keeperConf}
        lineNum=$[ ${serviceNameLine}+${enableOffset} ]
        sed -ri "${lineNum}s|enable: .*|enable: true|g" ${keeperConf}
      else
        serviceNameLine=`sed -n "/serviceName: prometheus\$/=" ${keeperConf}`
        enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
        lineNum=$[ ${serviceNameLine}+${enableOffset} ]
        sed -ri "${lineNum}s|enable: .*|enable: true|g" ${keeperConf}
        nohup ${installPath}/prometheus/prometheus --storage.tsdb.path=${installPath}/prometheus/data/ --config.file=${installPath}/prometheus/prometheus.yml --query.lookback-delta=15m --web.enable-lifecycle --web.listen-address=:8093 --web.config.file=${installPath}/prometheus/web.yml --log.level=error --web.enable-admin-api --enable-feature=promgl-at-modifier --storage.tsdb.retention.time=15y &>>${installPath}/prometheus/log/prometheus.log &
      fi
      chmod u+x ${installPath}/prometheus/promtool
      echo "prometheus 安装成功 "
    else
      echo "prometheus安装文件已存在，不需要重新安装"
      if [[  -f  ${configPath}/keeper.xml ]];then
        serviceNameLine=`sed -n "/<serviceName>prometheus<\/serviceName>/=" ${configPath}/keeper.xml`
        prefix=`sed -n $[${serviceNameLine}+2]p ${configPath}/keeper.xml |awk -F'>' '{print $2}'|awk -F'<' '{print $1}'`
        prefix=`echo ${prefix//&gt;/>}`
        prefix=`echo ${prefix//&amp;/&}`
        suffix=`sed -n $[${serviceNameLine}+3]p ${configPath}/keeper.xml |awk -F'>' '{print $2}'|awk -F'<' '{print $1}'`
        suffix=`echo ${suffix//&gt;/>}`
        suffix=`echo ${suffix//&amp;/&}`
        newLine=`sed -n "/serviceName: prometheus\$/=" ${configPath}/keeper.yaml`
        prefixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n prefix:|head -n 1|awk -F':' '{print $1}'`
        suffixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
        #content=`$[$newLine+$prefixOffset],$[$newLine+$suffixOffset-1]p ${configPath}/keeper.yaml`
        sed -i "$[$newLine+$prefixOffset],$[$newLine+$suffixOffset-1]d" ${configPath}/keeper.yaml
        echo "  prefix: '${prefix}'" >temp.yaml
        sed -i "$[$newLine+$prefixOffset-1]r temp.yaml"  ${configPath}/keeper.yaml

        suffixOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n suffix:|head -n 1|awk -F':' '{print $1}'`
        enableOffset=`sed -n "$[${newLine}+1],\$"p ${configPath}/keeper.yaml |grep -n enable:|head -n 1|awk -F':' '{print $1}'`

        #content=`$[$newLine+$suffixOffset],$[$newLine+$enableOffset-1]p ${configPath}/keeper.yaml`
        sed -i "$[$newLine+$suffixOffset],$[$newLine+$enableOffset-1]d" ${configPath}/keeper.yaml
        echo "  suffix: ' ${suffix}'" >temp.yaml
        sed -i "$[$newLine+$suffixOffset-1]r temp.yaml"  ${configPath}/keeper.yaml
        rm -f temp.yaml
      fi
      if [[ ${installType} == 4 ]];then
        #增加Prometheus认证
        if [[ ! -f ${installPath}/prometheus/web.yml ]]; then
      echo "basic_auth_users:
  admin: \$2a\$12\$nDpHH3wLUuXVrPDPkHVjgeZqH0bIjuc1hcN1Z1JiNMmmQjHDriawa" >> ${installPath}/prometheus/web.yml
        fi
        if [[ `cat  ${configPath}/keeper.yaml |grep "\-\-storage.tsdb.retention.time=.*d " | wc -l` -gt 0 ]];then
          save_day=`cat  ${configPath}/keeper.yaml |grep "\-\-storage.tsdb.retention.time=.*d " |awk -F"storage.tsdb.retention.time=" '{print $2}' |awk -F"d" '{print $1}'`
          sed -ri "s/--storage.tsdb.retention.time=.* /--storage.tsdb.retention.time=10y /g" ${configPath}/keeper.yaml
        fi
        if [[ `cat  ${configPath}/keeper.yaml |grep "\-\-web.enable-admin-api" | wc -l` == 0 ]];then
          sed -ri "s/--storage.tsdb.retention.time/--web.enable-admin-api --storage.tsdb.retention.time/g" ${configPath}/keeper.yaml
        fi
        if [[ `cat  ${configPath}/keeper.yaml |grep "\-\-enable-feature" | wc -l` == 0 ]];then
          sed -ri "s/--storage.tsdb.retention.time/--enable-feature=promgl-at-modifier --storage.tsdb.retention.time/g" ${configPath}/keeper.yaml
        fi
        sed -ri "s/--enable-feature=.* --storage.tsdb/--enable-feature=promgl-at-modifier --storage.tsdb/g" ${configPath}/keeper.yaml
        if [[ `cat  ${configPath}/keeper.yaml |grep "\-\-web.config.file=${installPath}/prometheus/web.yml" | wc -l` == 0 ]];then
          echo "增加prometheus 认证文件web.yml"
          sed -i "s|--web.listen-address=:8093|--web.listen-address=:8093 --web.config.file=${installPath}/prometheus/web.yml|g" ${configPath}/keeper.yaml
        fi
      fi
      if [[ `ps -ef|grep soft-install/prometheus/prometheus |grep -v grep| awk '{print $2}'|wc -l ` -gt 0 ]]; then
        echo "关闭prometheus进程"
        ps -ef |grep soft-install/prometheus/prometheus|grep -v grep | awk '{print $2}' | xargs kill -15
        sleep 5s
      fi
      echo "替换prometheus配置文件"
      \cp -r ${workdir}/jar/prometheus/prometheus.yml ${installPath}/prometheus/
      \cp -r ${workdir}/jar/prometheus/recoding_rule.yml  ${installPath}/prometheus/
      echo "prometheus重启成功"
    fi
    cd ${workdir}
    cp script/other/start.sh ${installPath}/prometheus
    cp script/other/stop.sh ${installPath}/prometheus
    cd ${workdir}
  else
        echo "当前节点无需安装prometheus"
  fi
}

#安装智能基线训练smart-baseline
function __InstallZcloud_smart_baseline {
     echo ""
     echo "开始安装 smart-baseline"
     #smart-baseline
     cd jar
     if [[ $(ps -ef|grep smart_baseline|grep -v grep|wc -l) -gt 0 ]];then
       ps -ef |grep smart_baseline|grep -v grep | awk '{print $2}' | xargs kill -9
       sleep 2s
     fi
     port=$(__CheckPort zcloud_smart_baseline)
     if [[ ${port} -gt 0 ]];then
       error "${port}端口已被占用，zcloud_smart_baseline安装失败,安装中断"
       exit 1
     fi
     #判断是否已解压
     if [[ -d ${installPath}/smart_baseline ]]; then
         rm -rf ${installPath}/smart_baseline
     fi
     #解压
     tar -xf smart_baseline.tar.gz -C "${installPath}"
     #修改配置文件
     cd ${workdir}
      __GenAppProper_smart_baseline
     #进入目录,执行脚本
     cd "${installPath}/smart_baseline"
     chmod u+x start
     nohup ${installPath}/smart_baseline/start >/dev/null 2>&1 &
     echo "smart-baseline启动：nohup ${installPath}/smart_baseline/start >/dev/null 2>&1 &"
     cd ${workdir}
     cp script/other/start.sh ${installPath}/smart_baseline
     cp script/other/stop.sh ${installPath}/smart_baseline
     echo "smart-baseline 安装完成"
}

#替换zoramon-mgr配置文件属性
function __GenAppProper_zoramon_mgr() {
    #typeset -r appName=${1}
    #echo "[Step $item]:  initialize Application [${appName}] ..."
    if [[ ${databaseType} = "MogDB" ]];then
      if [[ ${installNodeType} == "OneNode" ]]; then
        server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} single mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mogdb.user)
        dbaas_paasword=$(__readINI ${zcloudCfg} single mogdb.password)
      else
        server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_paasword=$(__readINI ${zcloudCfg} multiple mogdb.password)
      fi
      type=mogdb
    else
      if [[ ${installNodeType} == "OneNode" ]]; then
        server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} single mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mysql.username)
        dbaas_paasword=$(__readINI ${zcloudCfg} single mysql.root.paasword)
      else
        server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_paasword=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
      fi
      type=mysql
    fi
    #加密密码写到配置里
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_paasword}`

    cd ${workdir}
    echo "mgr connect db:"${server_ip}
    __ReplaceText "${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml" "type" "      type: \"${type}\""
    __ReplaceText "${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml" "user" "      user: \"${dbaas_username}\""
    __ReplaceText "${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml" "pwd" "      pwd: \"${dbaas_paasword_encode}\""
    __ReplaceText "${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml" "host" "      host: \"${server_ip}\""
    __ReplaceText "${installPath}/zcloud-zoramon-mgr/conf/zoramon.yaml" "port" "      port: ${server_port}"
}

#替换slowmon_mgr配置文件属性
function __GenAppProper_slowmon_mgr() {
    #typeset -r appName=${1}
    #echo "[Step $item]:  initialize Application [${appName}] ..."
    if [[ ${databaseType} = "MogDB" ]];then
      if [[ ${installNodeType} == "OneNode" ]]; then
        server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} single mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mogdb.user)
        dbaas_paasword=$(__readINI ${zcloudCfg} single mogdb.password)
      else
        server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_paasword=$(__readINI ${zcloudCfg} multiple mogdb.password)
      fi
      type=mogdb
    else
      if [[ ${installNodeType} == "OneNode" ]]; then
        server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} single mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mysql.username)
        dbaas_paasword=$(__readINI ${zcloudCfg} single mysql.root.paasword)
      else
        server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_paasword=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
      fi
      type=mysql
    fi
    #加密密码写到配置里
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_paasword}`

    cd ${workdir}
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "dbType" "dbType = ${type}"

    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mysqlUsername" "mysqlUsername = ${dbaas_username}"
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mysqlPassword" "mysqlPassword = ${dbaas_paasword_encode}"
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mysqlHost" "mysqlHost = ${server_ip}"
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mysqlPort" "mysqlPort = ${server_port}"

    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mogdbUsername" "mogdbUsername = ${dbaas_username}"
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mogdbPassword" "mogdbPassword = ${dbaas_paasword_encode}"
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mogdbHost" "mogdbHost = ${server_ip}"
    __ReplaceText "${installPath}/slowmon_mgr/conf/app.conf" "mogdbPort" "mogdbPort = ${server_port}"
}

#替换smart-baseline中配置文件
function __GenAppProper_smart_baseline {
    if [[ ${databaseType} = "MogDB" ]];then
      if [[ ${installNodeType} == "OneNode" ]]; then
        server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} single mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mogdb.user)
        dbaas_paasword=$(__readINI ${zcloudCfg} single mogdb.password)
      else
        server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_paasword=$(__readINI ${zcloudCfg} multiple mogdb.password)
      fi
      type=mogdb
    else
      if [[ ${installNodeType} == "OneNode" ]]; then
        server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} single mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mysql.username)
        dbaas_paasword=$(__readINI ${zcloudCfg} single mysql.root.paasword)
      else
        server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_paasword=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
      fi
      type=mysql
    fi
   #加密密码写到配置里
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_paasword}`

    cd ${workdir}

    __ReplaceTextSed "${installPath}/smart_baseline/config.json" " \\\"user\\\": \\\"user\\\"" " \\\"user\\\": \\\"${dbaas_username}\\\""
    __ReplaceTextSed "${installPath}/smart_baseline/config.json" "\\\"password\\\": \\\"password\\\"" "\\\"password\\\": \\\"${dbaas_paasword_encode}\\\""
    __ReplaceTextSed "${installPath}/smart_baseline/config.json" "\\\"host\\\": \\\"host\\\"" "\\\"host\\\": \\\"${server_ip}\\\""
    __ReplaceTextSed "${installPath}/smart_baseline/config.json" " \\\"port\\\": 3306" " \\\"port\\\": ${server_port}"
    if [[ ${databaseType} = "MogDB" ]];then
      __ReplaceTextSed "${installPath}/smart_baseline/config.json" " \\\"database\\\": \\\"series\\\"" " \\\"database\\\": \\\"zcloud\\\""
      __ReplaceTextSed "${installPath}/smart_baseline/config.json" " \\\"type\\\": \\\"mysql\\\"" " \\\"type\\\": \\\"mogdb\\\""
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

#部署监控组件
function __InstallMonitorComponent() {

    if [[  ${serviceName} == 'node-exporter' ]]; then
      __Install_node_exporter
    else
      echo "当前节点无需安装node-exporter"
    fi

    ## __InstallAgent

    cd ${workdir}
    if [[ ${installNodeType} == "OneNode" ]]; then
      outsidePrometheus=$(__readINI zcloud.cfg single dependence.outside.prometheus)
    else
      outsidePrometheus=$(__readINI zcloud.cfg multiple dependence.outside.prometheus)
    fi
    if [[  ${outsidePrometheus} = 0 && ${serviceName} == 'alertmanager' ]]; then
      __InstallAlertmanager
    else
      echo "当前节点无需安装alertmanager"
    fi
    if [[ -e ${workdir}/jar/zoramon-mgr && ${serviceName} == 'zoramon-mgr' ]]; then
      __InstallZcloud_zoramon_mgr
    else
      echo "当前节点无需安装zoramon-mgr"
    fi
    if [[ ${serviceName} == 'smart-baseline' ]]; then
      __InstallZcloud_smart_baseline
    else
      echo "当前节点无需安装smart-baseline"
    fi
    if [[ -e ${workdir}/jar/dbaas-mail-sender && ${serviceName} == 'dbaas-mail-sender' ]]; then
      __InstallDbaas_mail_sender
    else
      __RemoveServiceFromKeeper dbaas-mail-sender ${configPath}/keeper.yaml
      echo "当前节点无需安装dbaas-mail-sender"
    fi
    if [[ ${theme} != "zData" ]];then
      if [[  -e ${workdir}/jar/dbaas-wxwork-sender && ${serviceName} == 'dbaas-wxwork-sender' ]]; then
        __Install_alert_sender dbaas-wxwork-sender
      else
        __RemoveServiceFromKeeper dbaas-wxwork-sender ${configPath}/keeper.yaml
        echo "当前节点无需安装dbaas-wxwork-sender"
      fi

      if [[ -e ${workdir}/jar/dbaas-sender-common && ${serviceName} == 'dbaas-sender-common'  ]]; then
        __Install_alert_sender dbaas-sender-common
      else
        __RemoveServiceFromKeeper dbaas-sender-common ${configPath}/keeper.yaml
        echo "当前节点无需安装dbaas-sender-common"
      fi

      if [[ -e ${workdir}/jar/dbaas-zabbix-sender && ${serviceName} == 'dbaas-zabbix-sender' ]]; then
        __Install_alert_sender dbaas-zabbix-sender
      else
        __RemoveServiceFromKeeper dbaas-zabbix-sender ${configPath}/keeper.yaml
        echo "当前节点无需安装dbaas-zabbix-sender"
      fi
    fi
    if [[  ${serviceName} == 'slowmon_mgr' ]]; then
    __InstallZcloud_slowmon_mgr
    else
        echo "当前节点无需安装slowmon_mgr"
    fi

    sleep 20
    if [[ ${outsidePrometheus} = 0  && ${serviceName} == 'dbaas-registrationHub' ]]; then
    __InstallDbaas_registrationHub
    else
        echo "当前节点无需安装dbaas-registrationHub"
    fi

    echo "等待监控组件的启动，等待1分钟"
    sleep 60
}


function __queryOldRunCmd() {
  oldConf=${configPath}/keeper.xml
  if [[ -f ${oldConf} ]];then
    serviceNameLine=`sed -n "/<serviceName>${serviceName}<\/serviceName>/=" ${oldConf}`

    set +e
    jvmParam=`sed -n $[${serviceNameLine}+2]p keeper.xml |egrep -o  "\-Xms[0-9]*m \-Xmx[0-9]*m"`
    set -e
    if [[ ${jvmParam} == "" ]];then
      echo ""
    else
      echo "${jvmParam} -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=${logPath}/hserr/${jarName}_%p.log -Duser.timezone=GMT+08"
    fi
  else
    echo ""
  fi

}



