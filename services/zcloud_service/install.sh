
export nodeNum=#{nodeNum}
export installNodeType=#{installNodeType}
export installType=#{installType}
export installPath=#{installPath}
export homePath=#{homePath}
export workdir=#{workdir}
export osType=#{osType}
export osVersion=#{osVersion}
export oldRelease=#{oldRelease}
export release=#{release}
export realHostIp=#{hostIp}
export hostIp=#{hostIp}
export webIp=#{webIp}
export theme=#{theme}
export databaseType=#{databaseType}
export mysqluser=#{mysqluser}
export mysqlpassword=#{mysqlpassword}
export mysqlhost=#{mysqlhost}
export mysqlhostport=#{mysqlhostport}
export mogdbuser=#{mogdbuser}
export mogdbpassword=#{mogdbpassword}
export mogdbport=#{mogdbport}
export mogdbhost=#{mogdbhost}
export logPath="${homePath}/dbaas/zcloud-log"
export logFile="${homePath}/dbaas/zcloud-log/install.log"
export packagePath="${homePath}/dbaas/soft-package"
export bakPath="${homePath}/dbaas/soft-bak"
export configPath="${homePath}/dbaas/zcloud-config"
export javaIoTempDir="${logPath}/java-io-tmpdir"
export executeUser=#{executeUser}
export dependenceOutsideMogdb=#{dependenceOutsideMogdb}
export dependenceOutsideMySQL=#{dependenceOutsideMySQL}

. ./script/lib/common.sh
. ./script/lib/license/fresh_license_user_identifier.sh
. ./services/zcloud_service/zcloud_server_install.sh
. ./services/zcloud_service/monitor_component_install_unroot.sh


export ipPath=($( __ReadValue ${logPath}/evn.cfg ipPath))
export ssPath=($( __ReadValue ${logPath}/evn.cfg ssPath))
export oldVersion1=($( __ReadValue ${logPath}/evn.cfg oldVersion))
export bakTime=($( __ReadValue ${logPath}/evn.cfg bakTimeS))

export version=`cat ${workdir}/version.txt`
export versionPath=${logPath}/${version}


export serviceName=$1


function __InstallZcloudService() {
. ./script/lib/common.sh
. ./script/lib/license/fresh_license_user_identifier.sh
. ./services/zcloud_service/zcloud_server_install.sh
. ./services/zcloud_service/monitor_component_install_unroot.sh

  __QueryDatabaseInfo
  if [[ ${theme} == "zData" ]];then
    theme=zData
    databaseType=MySQL
    hostIp=127.0.0.1
    sed -ri  "s|mysql.root.paasword=.*|mysql.root.paasword=zdata_2019|g" ${workdir}/zcloud.cfg
  fi
  cd ${workdir}

  monitorComponent=("node-exporter" "alertmanager" "zoramon-mgr" "smart-baseline" "dbaas-mail-sender" "dbaas-wxwork-sender" "dbaas-sender-common" "dbaas-zabbix-sender" "slowmon_mgr")
  for item in "${monitorComponent[@]}";
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


  normalService=("dbaas-eureka-server" "dbaas-backend-damengdb" "dbaas-monitor" "dbaas-api-create-dg"
  "dbaas-configuration" "dbaas-mariadb" "dbaas-db-manage" "dbaas-create-shardingsphere"
  "dbaas-apigateway" "dbaas-infrastructure" "dbaas-operate-db" "dbaas-permissions"
  "dbaas-reposerver" "task-management" "dbaas-database-snapshot" "dbaas-backend-mogdb"
  "dbaas-common-db" "dbaas-lowcode-http-engine" "dbaas-management-database"
  "dbaas-management-host","dbaas-backend-script","dbaas-ogg-management","dbaas-common-backupcenter")
  for item in "${normalService[@]}";
    do
      if [[ "$item" == "$serviceName" ]]; then
        find_result=$(find ./jar -type f -iname "${serviceName}*.jar" -print -quit)
        if [[ -n "$find_result" ]]; then
          __InstallNormalZcloudService
          __CheckZcloudSingleServiceStatus
        break
        fi
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

  if [[ ${theme} != "zData" ]];then
    if [[ ${installType} = 4 ]]; then
        startTime=$(date +"%s%N")
        info "刷新license的软件标识 ..."
        __Fresh_user_identifier
        endTime=$(date +"%s%N")
        info "刷新license软件标识成功，耗时$( __CalcDuration ${startTime} ${endTime})"
    fi
  fi

  __ReplaceText ${logPath}/evn.cfg "realHostIp=" "realHostIp=${realHostIp}"
}

__ReplaceText ${logPath}/evn.cfg "step=" "step=${item}"
ipPath=`which ip`
ssPath=`which ss`
__ReplaceText ${logPath}/evn.cfg "ipPath=" "ipPath=${ipPath}"
__ReplaceText ${logPath}/evn.cfg "ssPath=" "ssPath=${ssPath}"
__ReplaceText ${logPath}/evn.cfg "theme=" "theme=${theme}"
__ReplaceText ${logPath}/evn.cfg "realHostIp=" "realHostIp=${hostIp}"

if [[ ${executeUser} = "root" ]];then
  function_call="$(declare -f __InstallZcloudService); __InstallZcloudService"
  su --preserve-environmen zcloud -c "HOME=$(getent passwd zcloud | cut -d: -f6); $function_call"
else
  __InstallZcloudService
fi

item=($( __ReadValue ${logPath}/evn.cfg step))
realHostIp=($( __ReadValue ${logPath}/evn.cfg realHostIp))


if [[ ${serviceName} == "changeZcloudCfg" ]]; then
  #修改zcloud配置文件内容
  __ChangeZcloudCfg
fi
