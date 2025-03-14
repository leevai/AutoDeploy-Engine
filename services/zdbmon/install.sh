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
logPath=${homePath}/dbaas/zcloud-log
configPath=${homePath}/dbaas/zcloud-config
logFile=${homePath}/dbaas/zcloud-log/install.log
javaIoTempDir="${logPath}/java-io-tmpdir"


. ./script/lib/common.sh
. ./script/lib/common_unroot.sh

function __InstallZdbmonMgr {
  zcloudCfg=${workdir}/config.cfg
  consulIp=$(__readINI ${zcloudCfg} common consul.ip)
  consulToken=$(__readINI ${zcloudCfg} common consul.token)
  serviceName=zdbmon-mgr
  env=prod
  consulHost=${consulIp}
  keeperConf=${configPath}/keeper.yaml
  if [[ ! -f ${keeperConf} ]];then
     cp  ${workdir}/conf/keeper.yaml ${configPath}
     sed -i "s|#installPath#|${installPath}|g" ${configPath}/keeper.yaml

     sed -i "s|#localIP#|${consulIp}|g" ${configPath}/keeper.yaml
     sed -i "s|#logPath#|${logPath}|g" ${configPath}/keeper.yaml
     sed -i "s|#consulToken#|${consulToken}|g" ${configPath}/keeper.yaml
  fi

  info "开始安装 zdbmon-mgr"
  if [[ $(ps -ef | grep zdbmon-mgr | grep -v grep | wc -l) -gt 0 ]]; then
    ps -ef | grep zdbmon-mgr | grep -v grep | awk '{print $2}' | xargs kill -9
    info "关闭zdbmon-mgr成功"
    sleep 2s
  fi
  if [[ -d ${installPath}/zdbmon-mgr ]];then
    rm -rf ${installPath}/zdbmon-mgr
  fi
  cp -r ${workdir}/jar/zdbmon-mgr ${installPath}
  consulPort=8500
  watchEnable=false
  CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
  jarPath=$(ls -t ${installPath}/${serviceName}/${serviceName}*.jar | head -n 1)
  homedir=$(cd ~ && pwd)
  source ${homedir}/.bashrc || true
  javapath=$(echo $JAVA_HOME)/bin/java
  runcmd="-Xms4096m -Xmx8092m -Djava.io.tmpdir=${javaIoTempDir} -XX:ParallelGCThreads=8 -XX:ErrorFile=#logPath#/hserr/${serviceName}_%p.log -Duser.timezone=GMT+08"
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
  cp ${workdir}/conf/logback/logback-default.xml ${installPath}/${serviceName}/config/
  sed -i 's#name="logHome" value=.*#name="logHome" value="'${logPath}/${serviceName}'/"/>#g' ${installPath}/${serviceName}/config/logback-default.xml
  mv ${installPath}/${serviceName}/config/logback-default.xml ${installPath}/${serviceName}/config/logback.xml

  info "nohup ${javapath} ${runcmd} -jar ${jarPath} --thin.offline=true --thin.root=${installPath}/pub_libs --springProfilesActive=${env} --consulHost=${consulIp} --consulPort=${consulPort} ${CONSUL_TOKEN_PARAM} --watchEnable=${watchEnable} >/dev/null 2>&1 &"
  nohup ${javapath} ${runcmd} -jar ${jarPath} --thin.offline=true --thin.root=${installPath}/pub_libs --springProfilesActive=${env} --consulHost=${consulIp} --consulPort=${consulPort} ${CONSUL_TOKEN_PARAM} --watchEnable=${watchEnable} >/dev/null 2>&1 &
  if [[ ${serviceNameLine} == "" ]];then

    serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}/conf/keeper.yaml`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}/conf/keeper.yaml>temp.yaml
    endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
    sed -i "${endLine}r temp.yaml" ${keeperConf}
    rm -f temp.yaml
    sed -i "s|#installPath#|${installPath}|g" ${configPath}/keeper.yaml

    sed -i "s|#localIP#|${consulIp}|g" ${configPath}/keeper.yaml
    sed -i "s|#logPath#|${logPath}|g" ${configPath}/keeper.yaml
    sed -i "s|#consulToken#|${consulToken}|g" ${configPath}/keeper.yaml
  else
    enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
    # keeper设置为自启动改服务
    lineNum=$[ ${serviceNameLine}+${enableOffset} ]
    sed -ri "${lineNum}s|enable: .*|enable: true|g" ${configPath}/keeper.yaml
  fi
  sed -ri "s|${installPath}/${serviceName}/.*\.jar|${jarPath}|g" ${configPath}/keeper.yaml
  cd ${workdir}
  \cp -f script/start.sh ${installPath}/${serviceName}
  \cp -f script/stop.sh ${installPath}/${serviceName}
}
function __MovePubLib() {
    if [[ -d ${installPath}/pub_libs ]];then
      if [[ -d  ${installPath}/pub_libs_bak_$(date '+%Y%m%d') ]];then
        rm -rf  ${installPath}/pub_libs_bak_$(date '+%Y%m%d')
      fi
      mv  ${installPath}/pub_libs ${installPath}/pub_libs_bak_$(date '+%Y%m%d')
    fi
    if [[ ! -d  ${installPath}/pub_libs ]];then
      mkdir -p ${installPath}/pub_libs
    fi

    rm -rf ${installPath}/pub_libs/repository
    \cp -fr ${workdir}/jar/pub_libs/repository ${installPath}/pub_libs
}



cd ${workdir}
if [[ ! -e ${homePath}/dbaas/zcloud-log ]];then
  mkdir -p ${homePath}/dbaas/zcloud-log
fi
if [[ ! -e  ${homePath}/dbaas/zcloud-config ]];then
  mkdir -p ${homePath}/dbaas/zcloud-config
fi
if [[ ! -e ${homePath}/dbaas/zcloud-log/java-io-tmpdir ]];then
  mkdir -p ${homePath}/dbaas/zcloud-log/java-io-tmpdir
fi

#__CheckJava

#__MovePubLib

__InstallZdbmonMgr
__InstallKeeper

#__InstallMonitorComponent




