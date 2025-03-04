homePath=#{homePath}
. ./script/lib/common.sh

installPath="${homePath}/dbaas/soft-install"
startTime=$(date +"%s%N")
cd /usr/lib/systemd/system
logPath=${homePath}/dbaas/zcloud-log
if [[ -f ${logPath}/evn.cfg ]];then
installType=($( __ReadValue ${logPath}/evn.cfg installType))
fi
if [[ ${installType} != "" ]];then
  #info "installType = ${installType}"
  #if [[ ${installType} = 1 ]];then
  #info "zCloud安装类型为全新安装"
  #elif [[ ${installType} = 2 ]];then
  #info "zCloud安装类型为root升级为非root"
  #else
  #info "zCloud安装类型为标准安装升级"
  #fi
  echo "${installType}"
else
  serviceCount=$(ls |egrep "dbaas-api-create-dg.service$|dbaas-apigateway.service$|dbaas-backend-damengdb.service$|dbaas-backend-db2.service$|dbaas-backend-mogdb.service$|dbaas-backend-oceanbase.service$|dbaas-backend-script.service$|dbaas-backend-sql-server.service$|dbaas-common-db.service$|dbaas-configuration.service$|dbaas-create-mongodb.service$|dbaas-create-postgres.service$|dbaas-create-redis.service$|dbaas-create-shardingsphere.service$|dbaas-database-snapshot.service$|dbaas-datachange-management.service$|dbaas-db-manage.service$|dbaas-eureka-server.service$|dbaas-infrastructure.service$|dbaas-mariadb.service$|dbaas-monitor-dashboard.service$|dbaas-monitor.service$|dbaas-operate-db.service$|dbaas-permissions.service$|dbaas-reposerver.service$|ai-business.service$|zcloud-ai-adapter.service$|zcloud_altermanager.service$|zcloud_slowmon_mgr.service$|zcloud_zoramon_mgr.service$|zcloud_smart_baseline.service$|zcloud_registrationHub.service$|consul.service$|task-management.service$"|wc -l)
  #info "${serviceCount}"
  if [[ ${serviceCount} -gt 0 ]];then
  installType=2
  #info "zCloud安装类型为root升级为非root"
  elif [[ ! -e ${installPath} || `ls ${installPath}|wc -l` = 0 ]];then
  installType=1
  #info "zCloud安装类型为全新安装"
  zCloudVersion=`ps -ef|grep dbaas-infrastructure|grep -v grep|awk '{print $(NF-4)}'|awk -F'/' '{print $NF}' |awk -F'-' '{print $(NF-1)}'`
  else
  installType=4
  #info "zCloud安装类型为标准安装升级"
  fi
  __ReplaceText ${logPath}/evn.cfg "installType=" "installType=${installType}"
  echo "${installType}"
fi