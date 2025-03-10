installPath=#{installPath}
configPath=#{configPath}
installType=#{installType}
outsidePrometheus=#{outsidePrometheus}
keeperConf=#{keeperConf}

. ./script/lib/dir_auth.sh
. ./script/lib/common.sh

#zcloudCfg=${workdir}/zcloud.cfg
#if [[ ${installNodeType} == "OneNode" ]]; then
#  outsidePrometheus=$(__readINI ${zcloudCfg} single dependence.outside.prometheus)
#else
#  outsidePrometheus=$(__readINI ${zcloudCfg} multiple dependence.outside.prometheus)
#fi
  tar -xf ./services/prometheus/soft_pkg/prometheus.tar.gz
  __CreateDir "${installPath}/prometheus"
  if [[ ! -e ${installPath}/prometheus/log ]];then
    mkdir -p ${installPath}/prometheus/log
  fi
  if [[ ! -f ${installPath}/prometheus/prometheus ]]; then
    #解压prometheus
    tar -xf ./services/prometheus/soft_pkg/prometheus.tar.gz -C "${installPath}"
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
    info "prometheus 安装成功 "
  else
    info "prometheus安装文件已存在，不需要重新安装"
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
      if [[ `cat  ${configPath}/keeper.yaml |grep "\-\-storage.tsdb.retention.time=.*d " | wc -l` > 0 ]];then
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
        info "增加prometheus 认证文件web.yml"
        sed -i "s|--web.listen-address=:8093|--web.listen-address=:8093 --web.config.file=${installPath}/prometheus/web.yml|g" ${configPath}/keeper.yaml
      fi
    fi
    if [[ `ps -ef|grep soft-install/prometheus/prometheus |grep -v grep| awk '{print $2}'|wc -l ` -gt 0 ]]; then
      info "关闭prometheus进程"
      ps -ef |grep soft-install/prometheus/prometheus|grep -v grep | awk '{print $2}' | xargs kill -15
      sleep 5s
    fi
    info "替换prometheus配置文件"
    \cp -r ./services/prometheus/soft_pkg/prometheus/prometheus.yml ${installPath}/prometheus/
    \cp -r ./services/prometheus/soft_pkg/prometheus/recoding_rule.yml  ${installPath}/prometheus/
    info "prometheus重启成功"
  fi
  cd ${workdir}
  cp script/other/start.sh ${installPath}/prometheus
  cp script/other/stop.sh ${installPath}/prometheus
  cd ${workdir}
