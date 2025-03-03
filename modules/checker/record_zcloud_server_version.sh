# 记录微服务的安装路径和版本
function __RecordPathAndVersion {
  if [[ $installType = 4 ]];then

    historyFile="${configPath}"/zcloud-history-info.cfg
    if [[ -f ${historyFile} ]];then
      rm -f "${historyFile}"
    fi
    touch "${historyFile}"
    if [[ $(ps -ef|grep dbaas-|grep -v grep |awk '{print $1" "$(NF-4)}'|grep dbaas|wc -l) > 0 ]];then
      echo "$(ps -ef|grep dbaas-|grep -v grep |awk '{print $1" "$(NF-4)}'|grep dbaas)" |while read line
      do
        __GetRunUser "${line}"
        jarPath1=$(echo "${line}" |awk -F' ' '{print $NF}')
        __GetServiceName "${jarPath1}"
        __GetServiceVersion "${jarPath1}"
        __GetServicePath "${jarPath1}"
        echo "[${serviceName}]">>"${historyFile}"
        echo "runUser=${runUser}">>"${historyFile}"
        echo "servicePath=${servicePath}">>"${historyFile}"
        echo "serviceVersion=${serviceVersion}">>"${historyFile}"
        echo "status=active">>"${historyFile}"
      done
    fi
    if [[ $(ps -ef|grep dbaas-|grep -v grep |awk '{print $1" "$(NF-1)}'|grep dbaas|wc -l) > 0 ]];then
      echo "$(ps -ef|grep dbaas-|grep -v grep |awk '{print $1" "$(NF-1)}'|grep dbaas)" |while read line
      do
        __GetRunUser "${line}"
        jarPath1=$(echo "${line}" |awk -F' ' '{print $NF}')
        __GetServiceName "${jarPath1}"
        __GetServiceVersion "${jarPath1}"
        __GetServicePath "${jarPath1}"
        echo "[${serviceName}]">>"${historyFile}"
        echo "runUser=${runUser}">>"${historyFile}"
        echo "servicePath=${servicePath}">>"${historyFile}"
        echo "serviceVersion=${serviceVersion}">>"${historyFile}"
        echo "status=active">>"${historyFile}"
      done
    fi

    if [[ $(ps -ef|grep ai-|grep -v grep |awk '{print $1" "$(NF-1)}'|grep ai|wc -l) > 0 ]];then
      echo "$(ps -ef|grep ai-|grep -v grep |awk '{print $1" "$(NF-1)}'|grep ai)" |while read line
      do
        __GetRunUser "${line}"
        jarPath1=$(echo "${line}" |awk -F' ' '{print $NF}')
        __GetServiceName "${jarPath1}"
        __GetServiceVersion "${jarPath1}"
        __GetServicePath "${jarPath1}"
        echo "[${serviceName}]">>"${historyFile}"
        echo "runUser=${runUser}">>"${historyFile}"
        echo "servicePath=${servicePath}">>"${historyFile}"
        echo "serviceVersion=${serviceVersion}">>"${historyFile}"
        echo "status=active">>"${historyFile}"
      done
    fi

    if [[ $(ps -ef|grep task-management|grep -v grep |awk '{print $1" "$(NF-4)}') > 0 ]]; then
      echo "$(ps -ef|grep task-management|grep -v grep |awk '{print $1" "$(NF-4)}')" |while read line
      do
        __GetRunUser "${line}"
        jarPath1=$(echo "${line}" |awk -F' ' '{print $NF}')
        __GetServiceName "${jarPath1}"
        __GetServiceVersion "${jarPath1}"
        __GetServicePath "${jarPath1}"
        echo "[${serviceName}]">>"${historyFile}"
        echo "runUser=${runUser}">>"${historyFile}"
        echo "servicePath=${servicePath}">>"${historyFile}"
        echo "serviceVersion=${serviceVersion}">>"${historyFile}"
        echo "status=active">>"${historyFile}"
      done
    fi
    info "记录微服务版本已完成"
  fi
}

function __GetServiceName {
  jarPath=$1
  serviceName=$(echo "${jarPath}" |awk -F'/' '{print $(NF-1)}')
}

function __GetServiceVersion {
  jarPath=$1
  serviceVersion=$(echo "${jarPath}" |awk -F'/' '{print $NF}' |awk -F'-' '{print $(NF-1)}')
}

function __GetServicePath {
  jarPath=$1
  servicePath=$(echo "${jarPath}" |awk -F'/' 'OFS="/" {$NF="";print $0}')
}

function __GetRunUser {
  param=$1
  runUser=$(echo "${param}" |awk -F' ' '{print $1}')
}