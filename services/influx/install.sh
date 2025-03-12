installPath=#{installPath}
workdir=#{workdir}
installNodeType=#{installNodeType}
installType=#{installType}
homePath=#{homePath}
release=#{release}
oldRelease=#{oldRelease}
logFile=#{logFile}

. ./script/lib/start_service.sh
. ./script/lib/common.sh
. ./script/lib/dir_auth.sh

function __InstallInfluxdb() {
  ##todo zdata不安装

#  if [[  $( __readINI nodeconfig/current.cfg service influx ) == ${nodeNum} && ${release} == "enterprise" ]]; then
      if [[ ! -e ${installPath}/soft/influx/log/ ]];then
        __CreateDir "${installPath}/soft/influx/log/"
      fi

      if [  `ps -ef|grep influxd|grep -v grep|wc -l ` -eq 0 ]; then
          # start influx
          echo "starting influx..."
          port=$(__CheckPort influxd)
          if [[ ${port} -gt 0 ]];then
            error "${port}端口已被占用，influxdb安装失败,安装中断"
            exit 1
          fi
          __CreateDir "${installPath}/soft/influx/"
          cd ${workdir}
          influx_server_port=($( __readINI zcloud.cfg aicure "aicure.influx.port" ))
          cp ${workdir}/soft/influx/influx ${installPath}/soft/influx/influx
          cp ${workdir}/soft/influx/influxd ${installPath}/soft/influx/influxd
          keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
          if [[ -f /usr/lib/systemd/system/influxdb.service ]];then
            export INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml
            /usr/lib/influxdb/scripts/influxd-systemd-start.sh &>>${installPath}/soft/influx/log/info.log &
            serviceNameLine=`sed -n "/serviceName: influx/=" ${keeperConf}`
            offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
            sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
            echo "- serviceName: influx
  path: /usr/bin/influxd
  prefix: export INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml;
  suffix: '/usr/lib/influxdb/scripts/influxd-systemd-start.sh &>>${installPath}/soft/influx/log/info.log &;'
  enable: true
  defaultProcessNum: 1">temp.yaml
            endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
            sed -i "${endLine}r temp.yaml" ${keeperConf}
            rm -f temp.yaml
          else
            nohup ${installPath}/soft/influx/influxd --http-bind-address=:$influx_server_port --engine-path=${installPath}/soft/influx/.influxdbv2/engine --bolt-path=${installPath}/soft/influx/.influxdbv2/influxd.bolt --pprof-disabled=true &>>${installPath}/soft/influx/log/info.log &

            sleep 5
            if [  `ps -ef|grep influxd|grep -v grep|wc -l ` -gt 0 ]; then
                success "start influx success"
                set +e
                __InstantiateInfluxdb
                set -e
            else
                error "start influx failed."
                exit 1
            fi
          fi
      else
        #重启
        if [[ (${oldVersion} != "" && ${oldVersion} < "3.5.2") && ! -f /usr/lib/systemd/system/influxdb.service ]];then
          if [[ `ps -ef|grep /influxd |grep -v grep| awk '{print $2}'|wc -l ` -gt 0 ]]; then
            echo "重启influx进程"
            ps -ef |grep /influxd|grep -v grep | awk '{print $2}' | xargs kill -9
            sleep 5s
          fi
          oldKeeperConf=${homePath}/dbaas/zcloud-config/keeper.xml
          if [[ -f ${oldKeeperConf} && `grep /usr/lib/influxdb/scripts/influxd-systemd-start.sh ${oldKeeperConf} |wc -l` -gt 0 ]];then
            export INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml
            /usr/lib/influxdb/scripts/influxd-systemd-start.sh &>>${installPath}/soft/influx/log/info.log &
            serviceNameLine=`sed -n "/serviceName: influx/=" ${keeperConf}`
            offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
            sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
            echo "- serviceName: influx
  path: /usr/bin/influxd
  prefix: export INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml;
  suffix: '/usr/lib/influxdb/scripts/influxd-systemd-start.sh &>>${installPath}/soft/influx/log/info.log &;'
  enable: true
  defaultProcessNum: 1">temp.yaml
            endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
            sed -i "${endLine}r temp.yaml" ${keeperConf}
            rm -f temp.yaml
          elif [[ `grep /usr/lib/influxdb/scripts/influxd-systemd-start.sh ${keeperConf}` -gt 0 ]]; then
            export INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml
            /usr/lib/influxdb/scripts/influxd-systemd-start.sh &>>${installPath}/soft/influx/log/info.log &
          else
            nohup ${installPath}/soft/influx/influxd --http-bind-address=:$influx_server_port --engine-path=${installPath}/soft/influx/.influxdbv2/engine --bolt-path=${installPath}/soft/influx/.influxdbv2/influxd.bolt --pprof-disabled=true &>>${installPath}/soft/influx/log/info.log &
          fi
        fi
        echo "Influxdb 已安装，不用重复安装."

      fi
      \cp -f script/other/start.sh ${installPath}/soft/influx
      \cp -f script/other/stop.sh ${installPath}/soft/influx
#    else
#        echo "当前节点无需安装influxdb"
#    fi

}

function __InstantiateInfluxdb() {
    echo "instantiate influx..."
    influx_account=($( __readINI zcloud.cfg aicure "aicure.influx.account" ))
    echo "${influx_account}"
    influx_password=($( __readINI zcloud.cfg aicure "aicure.influx.password" ))
    influx_org=($( __readINI zcloud.cfg aicure "aicure.influx.org" ))
    influx_bucket=($( __readINI zcloud.cfg aicure "aicure.influx.bucket" ))
    influx_token=($( __readINI zcloud.cfg aicure "aicure.influx.token" ))
    influx_server_port=($( __readINI zcloud.cfg aicure "aicure.influx.port" ))

    chmod 755 ./soft/influx/influx
    for ((i=1; i<=15; i++)); do
       sleep 10
       echo "${installPath}/soft/influx/influx setup --username ${influx_account} --password ***** --org ${influx_org} --bucket ${influx_bucket}  --retention 0 --host http://localhost:${influx_server_port} --token ${influx_token} --force"
       rtnMsg=`${installPath}/soft/influx/influx setup --username ${influx_account} --password ${influx_password} --org ${influx_org} --bucket ${influx_bucket}  --retention 0 --host http://localhost:${influx_server_port} --token ${influx_token} --force`
       echo "$rtnMsg"
       containMsg=$(echo $rtnMsg|grep "Error")
       if [[ $rtnMsg != "" && "$containMsg" == "" ]]; then
           success "Instantiate influxdb success"
           return
       else
          if [[ -f ${homedir}/.influxdbv2/configs ]];then
            rm -f ${homedir}/.influxdbv2/configs
          fi
           echo "init failed, reinit...."
       fi
    done
    error "Instantiate influxdb failed, please instantiate manually"
}


__InstallInfluxdb