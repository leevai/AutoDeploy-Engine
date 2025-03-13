#!/bin/bash


. ./script/lib/common.sh
. ./service/zcloud/zcloud_server_install.sh
. ./service/zcloud/monitor_component_install_unroot.sh

serviceName=$1

if [[ ${theme} == "zData" ]];then
  theme=zData
  databaseType=MySQL
  hostIp=127.0.0.1
  sed -ri  "s|mysql.root.paasword=.*|mysql.root.paasword=zdata_2019|g" ${workdir}/zcloud.cfg
fi
cd ${workdir}

monitorComponent=("node-exporter,alertmanager,zoramon-mgr,smart-baseline,dbaas-mail-sender,dbaas-wxwork-sender,dbaas-sender-common,dbaas-zabbix-sender,slowmon_mgr")
for item in "${list1[@]}"; 
  do
    if [[ "$item" == "$serviceName" ]]; then
        h2 "[安装监控组件 ... ${serviceName}";
            startTime=$(date +"%s%N")
            __InstallMonitorComponent
            endTime=$(date +"%s%N")
        echo "安装监控组件${serviceName} 完成，耗时$( __CalcDuration ${startTime} ${endTime})"
        break
    fi
  done


normalService=("dbaas-eureka-server","dbaas-backend-damengdb","dbaas-monitor","dbaas-api-create-dg",
"dbaas-configuration","dbaas-mariadb","dbaas-db-manage","dbaas-create-shardingsphere",
"dbaas-apigateway","dbaas-infrastructure","dbaas-operate-db","dbaas-permissions",
"dbaas-reposerver","task-management","dbaas-database-snapshot","dbaas-backend-mogdb",
"dbaas-common-db","dbaas-lowcode-http-engine","dbaas-management-database",
"dbaas-management-host")
for item in "${normalService[@]}";
  do
    if [[ "$item" == "$serviceName" ]]; then
      __InstallNormalZcloudService
      __CheckZcloudSingleServiceStatus
      break
    fi
  done


if [[ ${serviceName} == "dbaas-flyway-manage" ]]; then
  __InstallFlyway
  __CheckZcloudSingleServiceStatus
fi

if [[ ${serviceName} == "zdbmon-mgr" ]]; then
  __InstallZdbmonMgr
  __CheckZcloudSingleServiceStatus
fi

if [[ ${serviceName} == "offline_health_check_collector" ]]; then
  # 复制offline_health_check_collector 到/paasdata
  move_collector_to_paasdata
fi

__ReplaceText ${logPath}/evn.cfg "realHostIp=" "realHostIp=${realHostIp}"
