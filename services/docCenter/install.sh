#!/bin/bash
serviceAppName=#{serviceAppName}
nodeNum=#{nodeNum}
installNodeType=#{installNodeType}
installType=#{installType}
installPath=#{installPath}
homePath=#{homePath}
workdir=#{workdir}
osType=#{osType}
osVersion=#{osVersion}
oldRelease=#{oldRelease}
release=#{release}
realHostIp=#{hostIp}
theme=#{theme}
databaseType=#{databaseType}
mysqluser=#{mysqluser}
mysqlpassword=#{mysqlpassword}
mysqlhost=#{mysqlhost}
mysqlhostport=#{mysqlhostport}
mogdbuser=#{mogdbuser}
mogdbpassword=#{mogdbpassword}
mogdbport=#{mogdbport}
mogdbhost=#{mogdbhost}
logPath="${homePath}/dbaas/zcloud-log"
logFile="${homePath}/dbaas/zcloud-log/install.log"
packagePath="${homePath}/dbaas/soft-package"


function __InstallDocCenter {
   echo ""
   echo "开始安装文档中心"
   cd ${workdir}
   env=($(__readINI zcloud.cfg common "spring.profiles.active"))
   if [[ ${installNodeType} == "OneNode" ]]; then
     consulHost=$( __ReadValue nodeconfig/installparam.txt hostIp)
   else
     consulHost=$( __readINI zcloud.cfg multiple consul.host )
   fi
   consulPort=($(__readINI zcloud.cfg common "consul.port"))
   watchEnable=($(__readINI zcloud.cfg common "consul.watch.enable"))
   cd jar
   if [[ $(ps -ef|grep dbaas-doc-retrieval/doc-center-|grep -v grep|wc -l) -gt 0 ]];then
     ps -ef |grep dbaas-doc-retrieval/doc-center-|grep -v grep | awk '{print $2}' | xargs kill -9
     sleep 5s
   fi

   keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml

   port=$(__CheckPort dbaas-doc-retrieval)
   if [[ ${port} -gt 0 ]];then
     error "${port}端口已被占用，dbaas-doc-retrieval安装失败,安装中断"
     exit 1
   fi
   #判断是否已解压
   if [[ -d ${installPath}/dbaas-doc-retrieval ]]; then
       rm -rf ${installPath}/dbaas-doc-retrieval
   fi
   if [[ ! -e ${logPath}/dbaas-doc-retrieval/ ]];then
    __CreateDir "${logPath}/dbaas-doc-retrieval/"
   fi

   cp -r dbaas-doc-retrieval/ ${installPath}/
   #进入目录,执行脚本
   cd ${installPath}/dbaas-doc-retrieval

   javapath="`echo $JAVA_HOME`/bin/java"
   jarPath=`ls ${installPath}/dbaas-doc-retrieval/doc-center*.jar`
   cd ${workdir}
   __QueryDatabaseInfo
   cd ${installPath}/dbaas-doc-retrieval
   if [[ ${databaseType} == "MySQL" ]];then
     mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
     ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "CREATE DATABASE IF NOT EXISTS doc_center_base;"
   else
     result=`${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "select nspname from pg_catalog.pg_namespace where nspname = 'doc_center_base'"`
     if [[ ! (${result} =~ "doc_center_base") ]];then
       ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "CREATE SCHEMA doc_center_base authorization dbaas"
     fi
   fi
    memorySize=`free -h|grep Mem|awk '{print $2}'|sed -r "s/G$|Gi$//g"`
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
    jvmParam=($(__readINI ${workdir}/script/jvm_param/jvm_template.cfg ${jvmTemplate} dbaas-doc-retrieval ))
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

   sed -ri "s|logPath=.*|logPath=${logPath}/dbaas-doc-retrieval|g" config/application.properties
   #sed -ri "s|lucene.index.dir=.*|lucene.index.dir=${installPath}/dbaas-doc-retrieval/lucene/index/|g" config/application.properties
   #ui_url_port=($( __readINI ${workdir}/zcloud.cfg web "ui_url_port" ))
   #sed -ri "s|web.url.prefix=.*|web.url.prefix=http://${hostIp}:${ui_url_port}/zh/zcloud/|g" config/application.properties
   #sed -ri "s|upload.file.path=.*|upload.file.path=${installPath}/dbaas-doc-retrieval/attachment/|g" config/application.properties
   sed -i "s|\${logPath}|${logPath}/dbaas-doc-retrieval|g" config/logback.xml

   serviceName=dbaas-doc-retrieval
   keeperConf=${configPath}/keeper.yaml
   serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
   offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
   if [[ ${serviceNameLine} != "" ]];then
     sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
   fi
   serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
   offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
   if [[ ${serviceNameLine} != "" ]];then
     sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}conf/keeper.yaml>temp.yaml
     endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
     sed -i "${endLine}r temp.yaml" ${keeperConf}
     rm -f temp.yaml
     sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
     sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
     sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
     sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
   fi
   sed -ri "s|${installPath}/dbaas-doc-retrieval/doc-center.*\.jar|${jarPath}|g" ${configPath}/keeper.yaml
   serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
   sed -i "$[serviceNameLine+3]s/--spring.cloud.consul.config.acl-token=.*--/${CONSUL_TOKEN_PARAM} --/g" ${configPath}/keeper.yaml
   offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
   sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xms[0-9]*m|-Xms${jvmMin}m|g" ${keeperConf}
   sed -ri "${serviceNameLine},$[${serviceNameLine}+${offset}]s|\-Xmx[0-9]*m|-Xmx${jvmMax}m|g" ${keeperConf}
   __startFromKeeper dbaas-doc-retrieval
   cd ${workdir}
   cp script/start.sh ${installPath}/dbaas-doc-retrieval
   cp script/stop.sh ${installPath}/dbaas-doc-retrieval
   echo "安装文档中心完成"
   echo "sleep 120s"
   sleep 120s
}
