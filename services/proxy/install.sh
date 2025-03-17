#!/bin/bash
export serviceName=$1
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
proxyVersion=#{proxyVersion}
logPath="${homePath}/dbaas/zcloud-log"
logFile="${homePath}/dbaas/zcloud-log/install.log"
packagePath="${homePath}/dbaas/soft-package"


function __installZcloudProxy {
  if [[ ${installType} == 1 ]]; then
    if [[ ! -e /paasdata/Proxy ]];then
      mkdir -p /paasdata/Proxy
    fi
    cd paasdata
    if [[ ${osType} == "Kylin_arm" ]];then
      proxyFileName=`ls proxy_linux_arm*.tar.gz`
    else
      proxyFileName=`ls proxy_linux_x86*.tar.gz`
    fi


    \cp -f ${proxyFileName} /paasdata/Proxy
    \cp -f ${proxyFileName} /tmp
    chown -R zcloud:zcloud /paasdata/Proxy
    proxy_size=`du -b ${proxyFileName} |awk '{print $1}'`
    proxy_md5=`md5sum  ${proxyFileName} |awk '{print $1}'`
    sed -i "s|#proxy_file_name#|${proxyFileName}|g" ${workdir}/dbsqlfile/zcloud_paasdata_proxy_init.sql
    sed -i "s|#proxy_size#|${proxy_size}|g" ${workdir}/dbsqlfile/zcloud_paasdata_proxy_init.sql
    sed -i "s|#proxy_md5#|${proxy_md5}|g" ${workdir}/dbsqlfile/zcloud_paasdata_proxy_init.sql
    if [[ ${osType} == "Kylin_arm" ]];then
      proxySpecialType="KylinProxy"
    else
      proxySpecialType="proxyTar"
    fi
    sed -i "s|#proxySpecialType#|${proxySpecialType}|g" ${workdir}/dbsqlfile/zcloud_paasdata_proxy_init.sql
    cd ${workdir}

    if [[ ${databaseType} == "MySQL" ]];then
      mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      ${mysqlAddr} -uroot -p${mysqlpassword} -h${mysqlhost} -P${mysqlhostport} < ${workdir}/dbsqlfile/zcloud_paasdata_proxy_init.sql >> ${logFile} 2>&1
    else
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${mogdbhost} -p ${mogdbport} -U ${mogdbuser} -W ${mogdbpassword} -f dbsqlfile/zcloud_paasdata_proxy_init.sql
    fi

    if [[ ! -e /zcloud ]];then
      mkdir /zcloud
    fi

    tar -xf /tmp/${proxyFileName}  -C"/zcloud"
    chown -R zcloud:zcloud /zcloud/proxy
    /zcloud/proxy/root.sh /zcloud/proxy /zcloud 8200 ${realHostIp} ${realHostIp}
    sed -ri "s|server .*;|server ${realHostIp}:8080;|g" /zcloud/proxy/zcloud_proxy_nginx/conf/nginx.conf
    sed -i "s|proxy_pass http://yumserver/download/;|proxy_pass https://yumserver/download/;|g" /zcloud/proxy/zcloud_proxy_nginx/conf/nginx.conf
    sed -i "s|proxy_pass http://yumserver/pysrc/;|proxy_pass https://yumserver/pysrc/;|g" /zcloud/proxy/zcloud_proxy_nginx/conf/nginx.conf
    systemctl restart zcloud_proxy_nginx.service
    rm -f /tmp/${proxyFileName}
#    \cp -f paasdata/sys.tar.gz ${installPath}/packages/download
#    cd ${installPath}/packages/download
#    tar -xf sys.tar.gz
#    cd ${workdir}
  else
    echo "非全新安装部署，无需安装Proxy"
  fi
}


function __installZdataAgentAndProxy {
  # 卸载proxy
  if [[ ${installType} == "2" || ${installType} == "4"  ]];then
    bakTime="$(date '+%Y%m%d')"
    if [[ -d /opt/zcloud/proxy && (! -d /opt/zcloud/proxy.bak.${bakTime} ) ]];then
      cp -r /opt/zcloud/proxy /opt/zcloud/proxy.bak.${bakTime}
      /opt/zcloud/proxy/proxyOperate.sh proxyAgentServer uninstall
    fi

    rm -rf /opt/zcloud/proxy
  fi

  if [[ ! -e /paasdata/Agent ]];then
    mkdir -p /paasdata/Agent
  fi
  if [[ ! -e /paasdata/Proxy ]];then
    mkdir -p /paasdata/Proxy
  fi
  cd paasdata
  agentFileName=`ls agent_linux*.tar.gz`
  agentArmFileName=`ls agent_kylin*.tar.gz`
  if [[ ${osType} == "Kylin_arm" ]];then
    proxyFileName=`ls proxy_linux_arm*.tar.gz`
  else
    proxyFileName=`ls proxy_linux_x86*.tar.gz`
  fi

  \cp -f ${agentFileName} /paasdata/Agent
  \cp -f ${agentArmFileName} /paasdata/Agent
  \cp -f ${proxyFileName} /paasdata/Proxy
  \cp -f ${proxyFileName} /tmp
  chown -R zcloud:zcloud /paasdata/Agent
  chown -R zcloud:zcloud /paasdata/Proxy
  agent_size=`du -b ${agentFileName} |awk '{print $1}'`
  agent_arm_size=`du -b ${agentArmFileName} |awk '{print $1}'`
  proxy_size=`du -b ${proxyFileName} |awk '{print $1}'`
  agent_md5=`md5sum  ${agentFileName} |awk '{print $1}'`
  agent_arm_md5=`md5sum  ${agentArmFileName} |awk '{print $1}'`
  proxy_md5=`md5sum  ${proxyFileName} |awk '{print $1}'`
  sed -i "s|#agent_file_name#|${agentFileName}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#agent_arm_file_name#|${agentArmFileName}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#proxy_file_name#|${proxyFileName}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#agent_size#|${agent_size}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#agent_arm_size#|${agent_arm_size}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#proxy_size#|${proxy_size}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#agent_md5#|${agent_md5}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#agent_arm_md5#|${agent_arm_md5}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#proxy_md5#|${proxy_md5}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  if [[ ${osType} == "Kylin_arm" ]];then
    proxySpecialType="KylinProxy"
    proxyOsVersion="10"
    proxyOsType="Kylin"
    cpuArchitecture="aarch64"
  else
    proxySpecialType="proxyTar"
    proxyOsVersion="7.9"
    proxyOsType="Oracle"
    cpuArchitecture="x86_64"
  fi
  sed -i "s|#proxySpecialType#|${proxySpecialType}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#proxyOsVersion#|${proxyOsVersion}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#osType#|${proxyOsType}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  sed -i "s|#cpuArchitecture#|${cpuArchitecture}|g" ${workdir}/dbsqlfile/paasdata_init.sql
  cd ${workdir}
  mysqlhostport=($( __readINI zcloud.cfg single "mysql.service.port" ))
  __mysqlRootPwd=$(__readINI zcloud.cfg single mysql.root.paasword)
  mysqlIP=127.0.0.1
  mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
  ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlIP} -P${mysqlhostport} < ${workdir}/dbsqlfile/paasdata_init.sql >> ${logFile} 2>&1
  #groupadd zcloud
  #useradd -g zcloud zcloud -d /zcloud_proxy
  #chsh -s /bin/bash zcloud
  if [[ ! -e /opt/zcloud ]];then
    mkdir /opt/zcloud
  fi

  tar -xf /tmp/${proxyFileName}  -C"/opt/zcloud"
  chown -R zcloud:zcloud /opt/zcloud/proxy
  /opt/zcloud/proxy/root.sh /opt/zcloud/proxy /opt/zcloud 8200 ${realHostIp} ${realHostIp}
  sed -ri "s|server .*;|server ${realHostIp}:8080;|g" /opt/zcloud/proxy/zcloud_proxy_nginx/conf/nginx.conf
  sed -i "s|proxy_pass http://yumserver/download/;|proxy_pass https://yumserver/download/;|g" /opt/zcloud/proxy/zcloud_proxy_nginx/conf/nginx.conf
  sed -i "s|proxy_pass http://yumserver/pysrc/;|proxy_pass https://yumserver/pysrc/;|g" /opt/zcloud/proxy/zcloud_proxy_nginx/conf/nginx.conf
  systemctl restart zcloud_proxy_nginx.service
  rm -f /tmp/${proxyFileName}
  \cp -f paasdata/sys.tar.gz ${installPath}/packages/download
  cd ${installPath}/packages/download
  tar -xf sys.tar.gz
  cd ${workdir}
}

function __initProxy() {
  hostname=`cat /etc/hostname`
  cputype=`cat /proc/cpuinfo |grep 'model name' |sort -u|awk -F':' '{print $NF}'`
  cpunum=` cat /proc/cpuinfo | grep 'processor' | wc -l`
  oskernel=`uname -r`
  memorysize=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
  machinetype=`/usr/sbin/dmidecode -s  system-product-name`
  hardwareplatform=`uname -i`

  if [[ ${databaseType} == "MySQL" ]];then
    sed -i "s|#hostname#|${hostname}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#cputype#|${cputype}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#cpunum#|${cpunum}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#oskernel#|${oskernel}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#memorysize#|${memorysize}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#machinetype#|${machinetype}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#hardwareplatform#|${hardwareplatform}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#hostip#|${hostip}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#osversion#|${osVersion}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql
    sed -i "s|#proxyversion#|${proxyVersion}|g" ${workdir}/dbsqlfile/init_proxy_mysql.sql

    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    ${mysqlAddr} -uroot -p${mysqlpassword} -h${mysqlhost} -P${mysqlhostport} < ${workdir}/dbsqlfile/init_proxy_mysql.sql >> ${logFile} 2>&1
  else

    sed -i "s|#hostname#|${hostname}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#cputype#|${cputype}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#cpunum#|${cpunum}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#oskernel#|${oskernel}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#memorysize#|${memorysize}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#machinetype#|${machinetype}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#hardwareplatform#|${hardwareplatform}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#hostip#|${hostip}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#osversion#|${osVersion}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    sed -i "s|#proxyversion#|${proxyVersion}|g" ${workdir}/dbsqlfile/init_proxy_mogdb.sql
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${mogdbhost} -p ${mogdbport} -U ${mogdbuser} -W ${mogdbpassword} -f dbsqlfile/init_proxy_mogdb.sql
  fi

}


if [[ ${theme} == 'zData' ]]; then
    __installZdataAgentAndProxy
else
  __installZcloudProxy
  __initProxy
fi