#!/bin/bash
databaseType=#{databaseType}
workdir=#{workdir}
zcloudCfg=${workdir}/zcloud.cfg
installNodeType=#{installNodeType}
installPath=#{installPath}
installType=#{installType}
release=#{release}
oldRelease=#{oldRelease}
logFile=#{logFile}
homePath=#{homePath}

. ./script/lib/dir_auth.sh
. ./script/lib/start_service.sh

function __QueryDatabaseInfoKNWL() {
  if [[ ${databaseType} = "MogDB" ]];then
      driverName="org.opengauss.Driver"
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
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
        server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mogdb.password)
      fi
    else
      driverName="com.mysql.jdbc.Driver"
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
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mysql" ))
        server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)

      fi
    fi
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_password}`
}

function __InstallEkb {
  echo ""
  echo "开始安装专家知识库"
  if [[ ${installType} != 4 ]];then
    tar -xvf ${workdir}/soft/image.tar.gz -C"${installPath}/soft/nginx/nginx/html/expert-knwl-base"
  fi
  cd ${workdir}
  __QueryDatabaseInfoKNWL
  if [[ ${databaseType} == "MySQL" ]];then
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "CREATE DATABASE IF NOT EXISTS expert_knwl_base;"
  else
    result=`${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "select nspname from pg_catalog.pg_namespace where nspname = 'expert_knwl_base'"`
    if [[ ! (${result} =~ "expert_knwl_base") ]];then
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -f ${workdir}/other/expert_knwl_base.sql
    fi
  fi
   env=($(__readINI zcloud.cfg common "spring.profiles.active"))
   if [[ ${installNodeType} == "OneNode" ]]; then
     consulHost=$( __ReadValue nodeconfig/installparam.txt hostIp)
   else
     consulHost=$( __readINI zcloud.cfg multiple consul.host )
   fi
   consulPort=($(__readINI zcloud.cfg common "consul.port"))
   watchEnable=($(__readINI zcloud.cfg common "consul.watch.enable"))
   cd jar
   if [[ $(ps -ef|grep expert-knowledge-base/expert-knwl-base|grep -v grep|wc -l) -gt 0 ]];then
     ps -ef |grep expert-knowledge-base/expert-knwl-base|grep -v grep | awk '{print $2}' | xargs kill -9
     sleep 5s
   fi

   keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml

   port=$(__CheckPort expert-knowledge-base)
   if [[ ${port} -gt 0 ]];then
     error "${port}端口已被占用，expert-knowledge-base安装失败,安装中断"
     exit 1
   fi
   #判断是否已解压
   if [[ -d ${installPath}/expert-knowledge-base ]]; then
       rm -rf ${installPath}/expert-knowledge-base
   fi
   if [[ ! -e ${logPath}/expert-knowledge-base/ ]];then
    __CreateDir "${logPath}/expert-knowledge-base/"
   fi

   cp -r expert-knowledge-base/ ${installPath}/
   cp ${workdir}/conf/logback/logback-default.xml ${installPath}/expert-knowledge-base/config/
   mv ${installPath}/expert-knowledge-base/config/logback-default.xml ${installPath}/expert-knowledge-base/config/logback.xml
   #进入目录,执行脚本
   cd ${installPath}/expert-knowledge-base
   javapath="`echo $JAVA_HOME`/bin/java"
   jarPath=`ls ${installPath}/expert-knowledge-base/expert-knwl-base*.jar`
   sed -ri "s|ekb.lucene.index.dir=.*|ekb.lucene.index.dir=${installPath}/expert-knowledge-base/lucene/index/|g" config/application.properties
   sed -ri "s|upload.file.path=.*|upload.file.path=${installPath}/expert-knowledge-base/attachment/|g" config/application.properties
   sed -ri "s|database.address=.*|database.address=${server_ip}:${server_port}|g" config/application.properties
   sed -ri "s|spring.datasource.driverClassName=.*|spring.datasource.driverClassName=${driverName}|g" config/application.properties
   sed -ri "s|spring.datasource.username=.*|spring.datasource.username=${dbaas_username}|g" config/application.properties
   sed -ri "s|spring.datasource.password=.*|spring.datasource.password=${dbaas_paasword_encode}|g" config/application.properties
   sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}/expert-knowledge-base'/"/>#g' config/logback.xml
   serviceName=expert-knowledge-base
   keeperConf=${configPath}/keeper.yaml
   serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
   offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
   if [[ ${serviceNameLine} != "" ]];then
     sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
   fi
   serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
   offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}/conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
   if [[ ${serviceNameLine} != "" ]];then
     sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}/conf/keeper.yaml>temp.yaml
     endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
     sed -i "${endLine}r temp.yaml" ${keeperConf}
     rm -f temp.yaml
     sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
     sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
     sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
     sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
   fi
   sed -ri "s|${installPath}/expert-knowledge-base/expert-knwl-base.*\.jar|${jarPath}|g" ${configPath}/keeper.yaml
   __startFromKeeper expert-knowledge-base
   cd ${workdir}
   cp script/start.sh ${installPath}/expert-knowledge-base
   cp script/stop.sh ${installPath}/expert-knowledge-base
   echo "安装专家知识库完成"
}

if [[ ${release} != "forMogdb" ]];then
 __InstallEkb
fi


