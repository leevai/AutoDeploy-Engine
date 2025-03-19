
# nginx consul 配置文件和数据备份

function __BackUpNginxConf {

  if [[ ${bakTimePath} = "" ]];then
    bakTimePath="${bakPath}/$(date '+%Y%m%d')"
    __ReplaceText ${logPath}/evn.cfg "bakTimePath=" "bakTimePath=${bakTimePath}"
    __CreateDir "${bakTimePath}"
  fi
  if [[ $installType = 1 ]]; then
    info "全新安装不需要操作此步骤"
  elif [[ $installType = 2 ]];then
    cp /etc/nginx/nginx.conf "${bakTimePath}"
    info "nginx配置文件备份完成"
    if [[ -d /usr/share/nginx/static/image/ ]];then
      chown -R zcloud:zcloud /usr/share/nginx/static/image/
    fi
  else

    cp ${installPath}/soft/nginx/nginx/conf/nginx.conf "${bakTimePath}"
    chown -R zcloud:zcloud ${bakTimePath}
    info "nginx配置文件备份完成"
  fi

}

function __BackUpPrometheusConf {
  zcloudCfg=${workdir}/zcloud.cfg
  if [[ ${installNodeType} == "OneNode" ]]; then
    outsidePrometheus=$(__readINI ${zcloudCfg} single dependence.outside.prometheus)
  else
    outsidePrometheus=$(__readINI ${zcloudCfg} multiple dependence.outside.prometheus)
  fi
  if [[ ${outsidePrometheus} = 0 ]]; then
    if [[ ${bakTimePath} = "" ]];then
      bakTimePath="${bakPath}/$(date '+%Y%m%d')"
      __ReplaceText ${logPath}/evn.cfg "bakTimePath=" "bakTimePath=${bakTimePath}"
      __CreateDir "${bakTimePath}"
    fi
    if [[ $installType = 1 ]]; then
      info "全新安装不需要操作此步骤"
    else
      if [[ -f ${bakTimePath}/prometheus.yml ]];then
        info "prometheus配置文件备份完成"
      else
        if [[ `ps -ef|grep /prometheus/prometheus |grep -v grep|wc -l` = 0  ]]; then
          error "升级zCloud要求需要prometheus在运行中"
          exit 1
        fi

        prometheusPath=$(ps -ef|grep /prometheus/prometheus |grep -v grep |awk '{print $8}'|awk -F'/' 'OFS="/" {$NF="";print $0}')


        cp ${prometheusPath}prometheus.yml "${bakTimePath}"
        chown -R zcloud:zcloud ${bakTimePath}
        info "prometheus配置文件备份完成"
      fi
    fi
  else
    info "当前节点无需备份prometheus配置文件"
  fi
}

function __BackUpConsulData {
  bakTime="$(date '+%Y%m%d')"
  __ReplaceText ${logPath}/evn.cfg "bakTimeS=" "bakTimeS=${bakTime}"

  if [[ $installType = 1 ]]; then
    info "全新安装不需要操作此步骤"
  else
    if [[ ${bakTimePath} = "" ]];then
      bakTimePath="${bakPath}/$(date '+%Y%m%d')"
      __ReplaceText ${logPath}/evn.cfg "bakTimePath=" "bakTimePath=${bakTimePath}"
      __CreateDir "${bakTimePath}"
    fi
    if [[ `ps -ef|grep consul/consul|grep -v grep|wc -l` = 0 && $(  __ReadValue ${logPath}/evn.cfg consulPath) = "" ]];then
      error "升级zCloud需要consul正常运行"
      exit 1
    fi

    consulPath=$(ps -ef|grep /consul/consul |grep -v grep |awk '{print $8}')
    __ReplaceText ${logPath}/evn.cfg "consulPath=" "consulPath=${consulPath}"
    if [[ ${consulPath} != "" && $( __ReadValue ${logPath}/evn.cfg consulPath) != "" ]];then

      #如果存在consul token文件
      info "zcloud配置路径${configPath}"
      if [[ -f ${configPath}/consultoken.txt ]]; then
          consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
          export CONSUL_HTTP_TOKEN=${consulToken}
      fi

      ${consulPath} kv export >${bakTimePath}/consul_kv.json
      #如果存在consultoken文件，需要拷贝到新目录
      consulConfigPath=`ps -ef|grep /consul/consul |grep -v grep |awk '{print $13}'|awk -F '=' '{print $2}'`
      if [[ -f ${consulConfigPath}/consultoken.txt ]]; then
          cp ${consulConfigPath}/consultoken.txt ${bakTimePath}/
      fi
    fi
    chown -R zcloud:zcloud ${bakTimePath}
    info "consul配置文件备份完成"
  fi
}

function __BackUpMySQLConfig {
  if [[ ${bakTimePath} = "" ]];then
    bakTimePath="${bakPath}/$(date '+%Y%m%d')"
    __ReplaceText ${logPath}/evn.cfg "bakTimePath=" "bakTimePath=${bakTimePath}"
    __CreateDir "${bakTimePath}"
  fi
  if [[ ${installNodeType} == "OneNode" ]]; then
    outsideMysql=$( __readINI zcloud.cfg single "dependence.outside.mysql" )
  else
    outsideMysql=$( __readINI zcloud.cfg multiple "dependence.outside.mysql" )
  fi
  if [[ ${outsideMysql} = 1  ]]; then
    info "MySQL部署在其他主机，不需要此步骤"
  elif [[ $installType = 1 ]]; then
    info "全新安装不需要操作此步骤"
  elif [[ $installType = 2 ]];then
    cp /etc/my.cnf "${bakTimePath}"
    chown -R zcloud:zcloud ${bakTimePath}
    info "MySQL配置文件备份完成"
  else
    cp ${installPath}/soft/mysql/conf/my.cnf "${bakTimePath}"
    chown -R zcloud:zcloud ${bakTimePath}
    info "MySQL配置文件备份完成"
  fi

}