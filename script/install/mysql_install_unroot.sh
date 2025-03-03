#!/bin/bash
. lib/common_unroot.sh

installNodeType=$( __readINI zcloud.cfg installtype install.node.type )
nodeNum=$( __ReadValue nodeconfig/installparam.txt nodeNum)

function __initZDataConfig {
  if [[ ${installType} == "1" ]];then
    sed -i "s!#firstNodeIp#!${realHostIp}!g" dbsqlfile/init_zData_config.sql
    ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
    sed -i "s!#zCloudPort#!${ui_url_port}!g" dbsqlfile/init_zData_config.sql
    osVersion=`cat /etc/system-release|awk '{print $NF}'`
    cpuType=`cat /proc/cpuinfo |grep 'model name' |sort -u|awk -F':' '{print $NF}'`
    cpuNum=` cat /proc/cpuinfo | grep 'processor' | wc -l`
    memorySize=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
    machineType=`/usr/sbin/dmidecode -s  system-product-name`
    os_kernel=`uname -r`
    hostname=`hostname`
    hardwarePlatform=`uname -i`
    osStartTime=`who -b|awk '{print $(NF-1)" "$(NF)":00"}'`
    sed -i "s!#os_version#!$osVersion!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#cpu_type#!$cpuType!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#cpu_core_num#!$cpuNum!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#memory_size#!$memorySize!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#machine_type#!$machineType!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#os_kernel#!$os_kernel!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#host_name#!$hostname!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#hardware_platform#!$hardwarePlatform!g" dbsqlfile/init_zData_config.sql
    sed -i "s!#os_start_time#!$osStartTime!g" dbsqlfile/init_zData_config.sql
    __mysqlRootPwd=$(__readINI zcloud.cfg single mysql.root.paasword)
    mysqlhostport=$(__readINI ${zcloudCfg} single mysql.service.port)
    mysqlServiceIp=$(__readINI ${zcloudCfg} single mysql.service.ip)
    mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < dbsqlfile/init_zData_config.sql >> ${logFile} 2>&1
  fi
}




function __initMySQLData() {
  zcloudCfg=${workdir}/zcloud.cfg
  if [[ ${installNodeType} == "OneNode" ]]; then
    outsideMysql=$( __readINI zcloud.cfg single "dependence.outside.mysql" )
    mysqlServiceIp=$(__readINI ${zcloudCfg} single mysql.service.ip)
    eurekaIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
    mysqlhostport=$(__readINI ${zcloudCfg} single mysql.service.port)
    __mysqlRootPwd=$(__readINI ${zcloudCfg} single mysql.root.paasword)
  else
    outsideMysql=$( __readINI zcloud.cfg multiple "dependence.outside.mysql" )
    mysqlServiceIp=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
    eurekaIp=$( __readINI zcloud.cfg multiple web.ip )
    mysqlhostport=$(__readINI ${zcloudCfg} multiple mysql.service.port)
    __mysqlRootPwd=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
  fi

  initMySQL=($( __ReadValue ${logPath}/evn.cfg initMySQL))

  if [[ (${installType} == 1 || ${installType} == 2) && ${initMySQL} == "" ]];then
    __CreateDir ${installPath}/soft/mysql/soft
    __CreateDir ${installPath}/soft/mysql/data
    __CreateDir ${installPath}/soft/mysql/conf
    if [[ ${osType}  = "Kylin_arm" ]];then
      tar -zxf soft/mysql/mysql-5.7.34-kylin-aarch64.tar.gz -C "${installPath}/soft/mysql/"
    else
      tar -zxf soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz -C "${installPath}/soft/mysql/"
      info "mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql"
      mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql
    fi
    keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
    serviceNameLine=`sed -n "/serviceName: mysql\$/=" ${keeperConf}`
    if [[ ${serviceNameLine} != "" ]];then
      enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
      lineNum=$[ ${serviceNameLine} + ${enableOffset} ]
      sed -ri "${lineNum}s|enable: .*|enable: false|g" ${keeperConf}
    fi

    ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
    sed -i "/^set @zcloud_ip_addr_port/cset @zcloud_ip_addr_port=\"${mysqlServiceIp}:${ui_url_port}\";" other/clearData.sql
    sed -i "/^set @gateway_ip_addr/cset @gateway_ip_addr=\"${mysqlServiceIp}:${ui_url_port}\";" other/clearData.sql
    sed -i "/^set @monitor_ip_addr/cset @monitor_ip_addr=\"${mysqlServiceIp}\";" other/clearData.sql
    info "mysql -h${mysqlServiceIp} -uroot -p****** -P${mysqlhostport} -e \"select 1\">/dev/null 2>&1"
    set +e
    conn=`mysql -h${mysqlServiceIp} -uroot -p${__mysqlRootPwd} -P${mysqlhostport} -e "select 1"`
    retCode=$?
    if [[ ${retCode} != 0 ]];then
      error "连接数据库${mysqlServiceIp}:${mysqlhostport}失败，${conn}"
      exit 1
    fi
    set -e
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    zCloudIp=${realHostIp}
    info "start execute dbaas.sql"
    ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < dbsqlfile/dbaas.sql >> ${logFile} 2>&1
    info "execute dbaas.sql success"

    validate_password_status=`mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} -e "show variables like '%validate_password%'" 2>/dev/null | grep validate_password | wc -l`
    if [[ $validate_password_status == 0 ]]; then
      validate_password_sql="";
    else
      validate_password_sql="set GLOBAL validate_password_policy = 0;set GLOBAL validate_password_length= 1;"
    fi
    #${mysqlAddr}  -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;${validate_password_sql}grant all privileges on *.* to ${dbaas_username}@'%' identified by '${dbaas_paasword}'"
    if [[ $theme = "zData" ]]; then
      # dbaas.sql 脚本中会删除`mysql`.`user`表重新建,导致密码修改为dbaas@123
      # zData主题时,需要把数据库密码改回来

       mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;${validate_password_sql}alter user 'root'@'localhost' identified by '${__mysqlRootPwd}';alter user 'root'@'%' identified by '${__mysqlRootPwd}';flush privileges;"
       mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;delete from mysql.user where user ='dbaas';flush privileges;"
       mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;delete from mysql.user where user ='activiti';flush privileges;"
       mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;delete from mysql.user where user ='monitormanager';flush privileges;"
    else
      default_paasword=($( __readINI zcloud.cfg common "mysql.root.default.paasword" ))
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "alter user 'root'@'localhost' identified by '${__mysqlRootPwd}';"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "alter user 'root'@'%' identified by '${__mysqlRootPwd}';flush privileges;"

    fi
    info '基线数据导入完成'
    retCode=$?
    info "MySQL database init Sucessed"
    ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/clearData.sql >> ${logFile} 2>&1
    info '数据清理'
    retCode=$?

    if [[ ${retCode} == 0 ]]; then
      info "MySQL Clear History Data Sucessed"
    else
      info "MySQL Clear History Data failed,please manual use other/clearData.sql"
    fi
    __ReplaceText ${logPath}/evn.cfg "initMySQL=" "initMySQL=1"
  fi

}

function __updateComponentIp() {
    #解压mysql
    if [[ ! -f ${installPath}/soft/mysql/mysql/bin/mysql ]]; then
        mkdir -p ${installPath}/soft/mysql
        info "解压mysql安装包"
      if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
        tar -zxf soft/mysql/mysql-5.7.34-kylin-aarch64.tar.gz -C "${installPath}/soft/mysql/"
      else
        tar -zxf soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz -C "${installPath}/soft/mysql/"
        mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql
      fi
    fi

    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    zcloudCfg=${workdir}/zcloud.cfg
    if [[ ${installNodeType} == "OneNode" ]]; then
              mysqlhostport=$(__readINI ${zcloudCfg} single mysql.service.port)
              mysqlServiceIp=$(__readINI ${zcloudCfg} single mysql.service.ip)
              __mysqlRootPwd=$(__readINI ${zcloudCfg} single mysql.root.paasword)
              localIP=$( __ReadValue ${workdir}/nodeconfig/installparam.txt hostIp)

    else
              mysqlhostport=$(__readINI ${zcloudCfg} multiple mysql.service.port)
              mysqlServiceIp=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
              __mysqlRootPwd=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
              localIP=$( __ReadValue ${workdir}/nodeconfig/installparam.txt hostIp)

    fi
    echo "" >  other/updateAfterMysqlInstall.sql
    echo "use monitormanager;" >> other/updateAfterMysqlInstall.sql
    localIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
    info "当前节点配置ip ${localIp}"
    #如果当前节点是配置数
    agentNum=$( __readINI nodeconfig/current.cfg service agent)
    info "agent 配置信息 ${agentNum}"
    if [[ 1 == ${nodeNum} ]];then
      if [[ ${release} == "enterprise" ]];then
        ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/addComponent.sql >> ${logFile} 2>&1
      fi
      echo "DELETE FROM monitormanager.zcloud_platform_host;" >> other/updateAfterMysqlInstall.sql
      echo "INSERT INTO monitormanager.zcloud_platform_host (host_ip, host_port, host_type, install_dir, description) VALUES('${realHostIp}', 8100, 'Application', '${installPath}/agent/agent', '微服务');" >> other/updateAfterMysqlInstall.sql
      echo "DELETE FROM  monitormanager.zcloud_platform_component where name = 'dbaas-flyway-manage';" >> other/updateAfterMysqlInstall.sql
      echo "INSERT INTO monitormanager.zcloud_platform_component  values ('dbaas-flyway-manage', '${realHostIp}', '8066', 'service', '/dbaasFlywayManage/actuator/prometheus', '资料库管理微服务');" >> other/updateAfterMysqlInstall.sql
    else
      echo "REPLACE INTO monitormanager.zcloud_platform_host (host_ip, host_port, host_type, install_dir, description) VALUES('${realHostIp}', 8100, 'Application', '${installPath}/agent/agent', '微服务');" >> other/updateAfterMysqlInstall.sql
    fi


    #update service
    for service in "dbaas-common-db" "dbaas-backend-script" "dbaas-backend-sql-server" "dbaas-datachange-management" "dbaas-monitor" "dbaas-monitor-dashboard" "dbaas-api-create-dg" "dbaas-configuration" "dbaas-mariadb" "dbaas-db-manage" "dbaas-create-postgres" "dbaas-create-redis" "dbaas-create-shardingsphere" "dbaas-apigateway" "dbaas-infrastructure" "dbaas-operate-db" "dbaas-permissions" "dbaas-reposerver" "task-management" "dbaas-backend-db2" "dbaas-create-mongodb" "dbaas-database-snapshot" "dbaas-backend-damengdb" "dbaas-backend-mogdb" "dbaas-backend-oceanbase" "dbaas-ogg-management" "dbaas-flyway-manage" "dbaas-common-backupcenter" "dbaas-doc-retrieval" "dbaas-lowcode-atomic-ability" "dbaas-management-database" "dbaas-management-host" "expert-knowledge-base" "zdbmon-mgr";do
      serviceNum=$( __readINI nodeconfig/current.cfg service ${service})
      if [[ ${serviceNum} == ${nodeNum} ]];then
        echo "update zcloud_platform_component set ip='${realHostIp}' where \`name\` = '${service}';" >> other/updateAfterMysqlInstall.sql
      fi
    done

    info "配置updateAfterMysqlInstall.sql完成"


    info "${mysqlAddr} -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAfterMysqlInstall.sql"
    ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAfterMysqlInstall.sql >> ${logFile} 2>&1
    info "更新组件ip成功"
    if [[ 1 == ${nodeNum} && ${theme} != "zData" ]];then
      ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
      sed -i "/^set @zcloud_ip_addr_port/cset @zcloud_ip_addr_port=\"${localIP}:${ui_url_port}\";" other/rootUpdate.sql

      info "mysql -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/rootUpdate.sql >> ${logFile} 2>&1"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/rootUpdate.sql >> ${logFile} 2>&1
    fi

    if [[ ${release} == "standard" ]];then
      ##标准版需要禁用 扫描智能指标模板和训练智能指标 定时任务
      info "${mysqlAddr} -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_standard_mysql.sql"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_standard_mysql.sql >> ${logFile} 2>&1
    else
      ##非标准版需要启用 扫描智能指标模板和训练智能指标 定时任务
      info "${mysqlAddr} -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_mysql.sql"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_mysql.sql >> ${logFile} 2>&1
    fi

    if [[ ${release} == "standard" ]];then
      ##标准版需要禁用 扫描智能指标模板和训练智能指标 定时任务
      info "${mysqlAddr} -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_standard_mysql.sql"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_standard_mysql.sql >> ${logFile} 2>&1
    else
      ##非标准版需要启用 扫描智能指标模板和训练智能指标 定时任务
      info "${mysqlAddr} -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_mysql.sql"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/updateAiAlertTask_mysql.sql >> ${logFile} 2>&1
    fi

}
function __GetMysqlVersionNonRoot {

    if [[ $(${installPath}/soft/mysql/mysql/bin/mysql --version|awk '{print $5}') =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
    then
        mysql_version=${BASH_REMATCH[1]}
        mysql_version_part1=${BASH_REMATCH[2]}
        mysql_version_part2=${BASH_REMATCH[3]}

        note "MySQL version: $mysql_version"
    else
        error "Failed to parse MySQL version."
    fi
}

function __InstallMySQLCommon {
    info "开始安装MySQL "
    info "此步骤大概需要执行1m,请等待"
    __CreateDir ${installPath}/soft/mysql/soft
    __CreateDir ${installPath}/soft/mysql/data
    __CreateDir ${installPath}/soft/mysql/conf
    if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
      tar -zxf soft/mysql/mysql-5.7.34-kylin-aarch64.tar.gz -C "${installPath}/soft/mysql/"
    else
      tar -zxf soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz -C "${installPath}/soft/mysql/"
      mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql
    fi
    cd ${workdir}
    cp script/other/start.sh ${installPath}/soft/mysql
    cp script/other/stop.sh ${installPath}/soft/mysql

    if [[ ${installType} = 2 ]];then
      bakTimePath=($( __ReadValue ${logPath}/evn.cfg bakTimePath))
      \cp -f ${bakTimePath}/my.cnf  ${installPath}/soft/mysql/conf/
    else
      echo "[mysqld]
#GENERAL
datadir=${installPath}/soft/mysql/data
basedir=${installPath}/soft/mysql/mysql
socket=${installPath}/soft/mysql/data/mysql.sock
port=${mysqlhostport}
default_storage_engine=InnoDB
#INNODB
innodb_file_per_table=1
innodb_flush_method=O_DIRECT
#MYISAM
key_buffer_size=10M
tmp_table_size=32M
max_heap_table_size=32M
#query_cache_type=0
#query_cache_size=0
max_connections=2048
#table_cache=100
open_files_limit=65535
lower_case_table_names=1


log_bin=mysql-bin

server_id=1
expire_logs_days=10

bind_address=0.0.0.0
binlog_format=ROW
binlog_gtid_simple_recovery=1
binlog_rows_query_log_events=1
character_set_server=utf8mb4
enforce_gtid_consistency=1
explicit_defaults_for_timestamp=1
gtid_mode=ON
innodb_autoinc_lock_mode=2
innodb_buffer_pool_dump_at_shutdown=1
innodb_buffer_pool_dump_pct=40
innodb_buffer_pool_instances=16
innodb_buffer_pool_load_at_startup=1
innodb_buffer_pool_size=4G
innodb_doublewrite=1
innodb_flush_neighbors=0
innodb_io_capacity=2000
innodb_io_capacity_max=4000
innodb_lock_wait_timeout=5
innodb_log_buffer_size=64M
innodb_log_files_in_group=2
innodb_log_file_size=1G
innodb_lru_scan_depth=4096
innodb_max_undo_log_size=2G
innodb_online_alter_log_max_size=1G
innodb_open_files=65535
innodb_page_cleaners=8
innodb_print_all_deadlocks=0
innodb_purge_rseg_truncate_frequency=128
innodb_purge_threads=4
innodb_read_io_threads=16
innodb_sort_buffer_size=64M
innodb_stats_on_metadata=0
innodb_stats_persistent_sample_pages=64
innodb_status_file=0
innodb_status_output=0
innodb_status_output_locks=0
innodb_strict_mode=1
innodb_thread_concurrency=64
innodb_undo_log_truncate=1
innodb_write_io_threads=16
interactive_timeout=1800
join_buffer_size=4M
lock_wait_timeout=1800
log_bin_trust_function_creators=1
log_error_verbosity=2
log_queries_not_using_indexes=1
log_slow_admin_statements=1
log_slow_slave_statements=1
log_throttle_queries_not_using_indexes=10
log_timestamps=SYSTEM
long_query_time=1
loose_innodb_numa_interleave=1
master_info_repository=TABLE
max_allowed_packet=1G
max_connect_errors=1000000
min_examined_row_limit=100
query_cache_size=0
query_cache_type=0
read_buffer_size=8M
read_rnd_buffer_size=4M
relay_log_info_repository=TABLE
relay_log_recovery=1
slave_net_timeout=4
slave_parallel_type=LOGICAL_CLOCK
slave_parallel_workers=8
slave_rows_search_algorithms=INDEX_SCAN,HASH_SCAN
slave_transaction_retries=128
slow_query_log=1
sort_buffer_size=4M
sync_binlog=1
table_definition_cache=2048
table_open_cache=2048
table_open_cache_instances=64
thread_cache_size=64
transaction_isolation=READ-COMMITTED
wait_timeout=1800
skip_name_resolve=1
skip_ssl
" > ${installPath}/soft/mysql/conf/my.cnf
    fi
    #配置环境变量
    homedir=`cd ~ && pwd`
    if [[ ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  ) && ${osVersion} == 8.* ]]; then
          if [[ $(egrep "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" ${homedir}/.bashrc|wc -l) -eq 0 ]];then
              echo "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" >> ${homedir}/.bashrc
              echo "export PATH CLASSPATH JAVA_HOME" >> ${homedir}/.bashrc
          fi
    else
    __ReplaceText ${homedir}/.bashrc "PATH=" "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin"
    __ReplaceText ${homedir}/.bashrc "export" "export PATH CLASSPATH JAVA_HOME"
    fi
    source ${homedir}/.bashrc || true
}

function __InstallMySQLNonRoot {
    __InstallMySQLCommon
    ${installPath}/soft/mysql/mysql/bin/mysqld --defaults-file=${installPath}/soft/mysql/conf/my.cnf --initialize-insecure --user=zcloud
    sleep 10
    ${installPath}/soft/mysql/mysql/bin/mysqld_safe --defaults-file=${installPath}/soft/mysql/conf/my.cnf --user=zcloud &

    sleep 20
    ${installPath}/soft/mysql/mysql/bin/mysql -u root -S ${installPath}/soft/mysql/data/mysql.sock -e "create user 'root'@'%' identified by '${__mysqlRootPwd}';grant all on *.* to 'root'@'%' with grant option;alter user 'root'@'localhost' identified by '${__mysqlRootPwd}';"


    retCode=$?
    # retCode=0
    echo "${retCode}"
    if [[ ${retCode} == 0 ]]; then
        info "Install MySQL Sucessed"
    else
        error "Install MySQL Failed"
        exit 1
    fi

}

function __CheckMysqlNonRoot {

  if [[ $(ps -ef|grep mysqld|grep -v grep|wc -l) -gt 0 ]];then
    info "已安装过MySQL, 无需重复安装"
  else
    if ! ${installPath}/soft/mysql/mysql/bin/mysql --version &> /dev/null
    then
        __InstallMySQLNonRoot
    fi
    __GetMysqlVersionNonRoot


    if [[ "${mysql_version_part1}" -gt "5" ]]; then
      info "MySQL Check Sucessed , Version gt 5"
    elif [[ "${mysql_version_part1}" -eq "5" ]]; then
        if [[ "${mysql_version_part2}"  -ge "7" ]]; then
            info "MySQL Check Sucessed , Version ge 5.7"
        else
            info "MySQL Check Failed , Version must gt 5.7, please Uninstall and reinstall 5.7.*"
            exit 1
        fi
    else
        info "MySQL Check Failed , Version must gt 5, please Uninstall and reinstall 5.7.*"
        exit 1

    fi
  fi
}

function __StartInitMySQLNonRoot {

      cd ${workdir}
      localIP=${hostIp}
      mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      zcloudCfg=${workdir}/zcloud.cfg
      if [[ ${installNodeType} == "OneNode" ]]; then
        mysqlhostip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        mysqlhostport=$(__readINI ${zcloudCfg} single mysql.service.port)

      else
        mysqlhostip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        mysqlhostport=$(__readINI ${zcloudCfg} multiple mysql.service.port)

      fi

      info 'mysqlip为'${mysqlServiceIp}
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} -e  "reset master"
      mysqlStatus=`${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} -e "show databases" 2>/dev/null |grep mysql | wc -l `

      while [[ $mysqlStatus == 0 ]]
      do
        sleep 10
        info "MySQL database init ..... "
        mysqlStatus=`${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} -e "show databases" 2>/dev/null |grep mysql | wc -l`
      done
      info "start execute dbaas.sql"
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < dbsqlfile/dbaas.sql >> ${logFile} 2>&1
      info "execute dbaas.sql success"

      validate_password_status=`mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} -e "show variables like '%validate_password%'" 2>/dev/null | grep validate_password | wc -l`
      if [[ $validate_password_status == 0 ]]; then
        validate_password_sql="";
      else
        validate_password_sql="set GLOBAL validate_password_policy = 0;set GLOBAL validate_password_length= 1;"
      fi

      if [[ $theme = "zData" ]]; then
        # dbaas.sql 脚本中会删除`mysql`.`user`表重新建,导致密码修改为dbaas@123
        # zData主题时,需要把数据库密码改回来
        mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "alter user 'root'@'localhost' identified by '${__mysqlRootPwd}';alter user 'root'@'127.0.0.1' identified by '${__mysqlRootPwd}';flush privileges;"
      else
        default_paasword=($( __readINI zcloud.cfg common "mysql.root.default.paasword" ))
        ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "alter user 'root'@'localhost' identified by '${__mysqlRootPwd}';"
        ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "alter user 'root'@'%' identified by '${__mysqlRootPwd}';flush privileges;"
      fi
      info '基线数据导入完成'
      retCode=$?

      if [[ ${retCode} == 0 ]]; then
        touch .mysqlinit
        if [[ ${theme} != "zData" ]];then
          dbaas_username=($( __readINI zcloud.cfg common "mysql.server.dbaas.username" ))
          dbaas_paasword=($( __readINI zcloud.cfg common "mysql.server.dbaas.paasword" ))
          activiti_username=($( __readINI zcloud.cfg common "mysql.server.activiti.username" ))
          activiti_paasword=($( __readINI zcloud.cfg common "mysql.server.activiti.paasword" ))
          scheduler_username=($( __readINI zcloud.cfg common "mysql.server.scheduler.username" ))
          scheduler_paasword=($( __readINI zcloud.cfg common "mysql.server.scheduler.paasword" ))
          monitormanager_username=($( __readINI zcloud.cfg common "mysql.server.monitormanager.username" ))
          monitormanager_paasword=($( __readINI zcloud.cfg common "mysql.server.monitormanager.paasword" ))
          taskmanagement_username=($( __readINI zcloud.cfg common "mysql.server.taskmanagement.username" ))
          taskmanagement_password=($( __readINI zcloud.cfg common "mysql.server.taskmanagement.password" ))

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;grant all privileges on *.* to ${dbaas_username}@'%' identified by '${dbaas_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on activiti.* to ${activiti_username}@'%' identified by '${activiti_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on scheduler.* to ${scheduler_username}@'%' identified by '${scheduler_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on *.* to ${monitormanager_username}@'%' identified by '${monitormanager_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on *.* to ${dbaas_username}@'localhost' identified by '${dbaas_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on taskmanagement.* to ${taskmanagement_username}@'%' identified by '${taskmanagement_password}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on dbaas.* to ${dbaas_username}@'localhost' identified by '${dbaas_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on activiti.* to ${activiti_username}@'localhost' identified by '${activiti_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on scheduler.* to ${scheduler_username}@'localhost' identified by '${scheduler_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on *.* to ${monitormanager_username}@'localhost' identified by '${monitormanager_paasword}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "grant all privileges on taskmanagement.* to ${taskmanagement_username}@'%' identified by '${taskmanagement_password}'"

          ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e " set GLOBAL max_connections=1024;"
          info "MySQL database init Sucessed"
        else
          info "MySQL database init Sucessed"
        fi


        ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/clearData.sql >> ${logFile} 2>&1
        info '数据清理'
        retCode=$?

        if [[ ${retCode} == 0 ]]; then
          info "MySQL Clear History Data Sucessed"
        else
          info "MySQL Clear History Data failed,please manual use other/clearData.sql"
        fi

      else
          error "MySQL database init failed,please manual import dbsqlfile/dbaas.sql "
          rm .mysqlinit
      fi
      info "MySQL database already initialized "
}

function __InstallMysql() {
  zcloudCfg=${workdir}/zcloud.cfg
  if [[ ${installNodeType} == "OneNode" ]]; then
                outsideMysql=$( __readINI zcloud.cfg single "dependence.outside.mysql" )
                mysqlServiceIp=$(__readINI ${zcloudCfg} single mysql.service.ip)
                eurekaIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
                mysqlhostport=$(__readINI ${zcloudCfg} single mysql.service.port)
                __mysqlRootPwd=$(__readINI ${zcloudCfg} single mysql.root.paasword)
   else
                outsideMysql=$( __readINI zcloud.cfg multiple "dependence.outside.mysql" )
                mysqlServiceIp=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
                eurekaIp=$( __readINI zcloud.cfg multiple web.ip )
                mysqlhostport=$(__readINI ${zcloudCfg} multiple mysql.service.port)
                __mysqlRootPwd=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)
  fi


  if [[ $( __readINI nodeconfig/current.cfg service mysql ) == ${nodeNum} && ${outsideMysql} = 0 ]]; then

    startTime=$(date +"%s%N")
    if [[ ! -f /usr/lib/systemd/system/mysqld.service && ${installType} = 4  && ${outsideMysql} = 0 ]];then
      if [[ `ps -ef|grep mysqld|grep -v grep |wc -l` -eq 0 ]];then
        error "升级需要MySQL正常运行"
        exit 1
      fi
    fi
    if [[ ${installType} = 4 && ! -f /usr/lib/systemd/system/mysqld.service ]];then
      if [[ -d ${installPath}/soft/mysql ]];then
        \cp -f ${workdir}script/other/start.sh ${installPath}/soft/mysql
        \cp -f ${workdir}script/other/stop.sh ${installPath}/soft/mysql

         # 升级的时候清除没有用的用户
        info "delete mysql user not used......"
        mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
        ${mysqlAddr}  -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;delete from mysql.user where user ='activiti';flush privileges;"
        ${mysqlAddr}  -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} mysql -e "flush privileges;delete from mysql.user where user ='monitormanager';flush privileges;"
      fi
      info "标准升级不需要此步骤"
      h2 "[Step $item/$stepTotal]:  MySQL initialize  ...";  let item+=1

      info "标准升级不需要此步骤"
      return
    fi

    #修改zcloud.cfg文件，动态获取eureka的IP地址

    sed -i "/^eureka.client.serviceUrl.defaultZone/ceureka.client.serviceUrl.defaultZone=http://${eurekaIp}:8761/eureka/" zcloud.cfg

    if [[ ${outsideMysql} = 1 ]];then
      #依赖外部mysql逻辑开始
      __CreateDir ${installPath}/soft/mysql/soft
      __CreateDir ${installPath}/soft/mysql/data
      __CreateDir ${installPath}/soft/mysql/conf
      if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
        tar -zxf soft/mysql/mysql-5.7.34-kylin-aarch64.tar.gz -C "${installPath}/soft/mysql/"
      else
        tar -zxf soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz -C "${installPath}/soft/mysql/"
        info "mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql"
        mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql
      fi
      keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
      serviceNameLine=`sed -n "/serviceName: mysql\$/=" ${keeperConf}`
      enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
      lineNum=$[ ${serviceNameLine} + ${enableOffset} ]
      sed -ri "${lineNum}s|enable: .*|enable: false|g" ${keeperConf}

      ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
      sed -i "/^set @zcloud_ip_addr_port/cset @zcloud_ip_addr_port=\"${mysqlServiceIp}:${ui_url_port}\";" other/clearData.sql
      sed -i "/^set @gateway_ip_addr/cset @gateway_ip_addr=\"${mysqlServiceIp}:${ui_url_port}\";" other/clearData.sql
      sed -i "/^set @monitor_ip_addr/cset @monitor_ip_addr=\"${mysqlServiceIp}\";" other/clearData.sql
      if [[ ${installType} = 1 ]];then
        info "依赖外部安装的MySQL,无需在本机上安装"

        info "mysql -h${mysqlServiceIp} -uroot -p****** -P${mysqlhostport} -e \"select 1\">/dev/null 2>&1"
        set +e
        conn=`mysql -h${mysqlServiceIp} -uroot -p${__mysqlRootPwd} -P${mysqlhostport} -e "select 1"`
        retCode=$?
        if [[ ${retCode} != 0 ]];then
          error "连接数据库${mysqlServiceIp}:${mysqlhostport}失败，${conn}"
          exit 1
        fi
        set -e
        endTime=$(date +"%s%N")
        info "安装MySQL完成，耗时$( __CalcDuration ${startTime} ${endTime})"
        h2 "[Step $item/$stepTotal]:  MySQL initialize  ...";  let item+=1
        startTime=$(date +"%s%N")
        info "此步骤大概需要执行1m,请等待"
        __StartInitMySQLNonRoot
        endTime=$(date +"%s%N")
        info "MySQL initialize 完成，耗时$( __CalcDuration ${startTime} ${endTime})"
      else
        ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
        sed -i "/^set @zcloud_ip_addr_port/cset @zcloud_ip_addr_port=\"${mysqlServiceIp}:${ui_url_port}\";" other/rootUpdate.sql

        info "mysql -uroot -p***** -h${mysqlServiceIp} -P${mysqlhostport} < other/rootUpdate.sql >> ${logFile} 2>&1"
        mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/rootUpdate.sql >> ${logFile} 2>&1
      fi
      #依赖外部mysql逻辑开始
    else
      if [[ $(ps -ef|grep mysqld|grep zcloud|grep -v grep|wc -l) -gt 0 ]];then
        info "mysql 已安装，无需重复安装"
        endTime=$(date +"%s%N")
        info "安装MySQL完成，耗时$( __CalcDuration ${startTime} ${endTime})"
        h2 "[Step $item/$stepTotal]:  MySQL initialize  ...";  let item+=1
        startTime=$(date +"%s%N")
        info "无需initialize MySQL"
        endTime=$(date +"%s%N")
        info "MySQL initialize 完成，耗时$( __CalcDuration ${startTime} ${endTime})"
      elif [[ $( __readINI nodeconfig/current.cfg service mysql )  == 1 && $(ps -ef|grep mysqld|grep zcloud|grep -v grep|wc -l) = 0 && ! -f /usr/lib/systemd/system/mysqld.service ]]; then
        typeset -r nodeType=${installNodeType}
        cd ${workdir}
        # shellcheck disable=SC2005
         #修改clearData.sql文件，初始化登录IP地址和监控数据库地址
        ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
        sed -i "/^set @zcloud_ip_addr_port/cset @zcloud_ip_addr_port=\"${mysqlServiceIp}:${ui_url_port}\";" other/clearData.sql
        sed -i "/^set @gateway_ip_addr/cset @gateway_ip_addr=\"${mysqlServiceIp}:${ui_url_port}\";" other/clearData.sql
        sed -i "/^set @monitor_ip_addr/cset @monitor_ip_addr=\"${mysqlServiceIp}\";" other/clearData.sql

        # 检查是否安装mysql

        __CheckMysqlNonRoot
        endTime=$(date +"%s%N")
        info "安装MySQL完成，耗时$( __CalcDuration ${startTime} ${endTime})"
        h2 "[Step $item/$stepTotal]:  MySQL initialize  ...";  let item+=1
        startTime=$(date +"%s%N")
        info "此步骤大概需要执行1m,请等待"
        __StartInitMySQLNonRoot
        endTime=$(date +"%s%N")
        info "MySQL initialize 完成，耗时$( __CalcDuration ${startTime} ${endTime})"

      else
        if [[ -f /usr/lib/systemd/system/mysqld.service ]];then
          __InstallMySQLCommon
          dataDir=($( __ReadValue ${logPath}/evn.cfg mysqlDataDir))
          sed -i "s|${installPath}/soft/mysql/data|${dataDir}|g" ${installPath}/soft/mysql/conf/my.cnf
          keeperConf=${homePath}/dbaas/zcloud-config/keeper.yaml
          serviceNameLine=`sed -n "/serviceName: mysql\$/=" ${keeperConf}`
          enableOffset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n enable:|head -n 1|awk -F':' '{print $1}'`
          lineNum=$[ ${serviceNameLine} + ${enableOffset} ]
          sed -ri "${lineNum}s|enable: .*|enable: true|g" ${keeperConf}
          ${installPath}/soft/mysql/mysql/bin/mysqld_safe --defaults-file=${installPath}/soft/mysql/conf/my.cnf --user=zcloud &
          sleep 60
        fi
        h2 "[Step $item/$stepTotal]:  MySQL initialize  ...";  let item+=1
        if [[ ${installType} = 2 ]];then
          ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
          sed -i "/^set @zcloud_ip_addr_port/cset @zcloud_ip_addr_port=\"${mysqlServiceIp}:${ui_url_port}\";" other/rootUpdate.sql

          info "mysql -uroot -p****** -h${mysqlServiceIp} -P${mysqlhostport} < other/rootUpdate.sql >> ${logFile} 2>&1"
          mysql -uroot -p${__mysqlRootPwd} -h${mysqlServiceIp} -P${mysqlhostport} < other/rootUpdate.sql >> ${logFile} 2>&1
        else
          info "无需initialize MySQL"
        fi
      fi
      if [[ -d ${installPath}/soft/mysql ]];then
        \cp -f ${workdir}script/other/start.sh ${installPath}/soft/mysql
        \cp -f ${workdir}script/other/stop.sh ${installPath}/soft/mysql
      fi
    fi
    if [[ ${outsideMysql} == 1 ]];then
      mysqlIp=${mysqlServiceIp}
    else
      mysqlIp=${hostIp}
    fi
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    if [[ ${release} == "standard" ]];then
      ##标准版需要加权限白名单
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlIp} -P${mysqlhostport} < ${workdir}other/addStandardPermissionBlack.sql >> ${logFile} 2>&1

    fi
    if [[ ${release} == "enterprise" && ${oldRelease} == "standard" ]];then
      ##企业版需要删除权限白名单
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlIp} -P${mysqlhostport} < ${workdir}other/deleteStandardPermissionBlack.sql >> ${logFile} 2>&1
    fi


  else
        info "当前节点无需安装mysql"
  fi
}

function __deletePlatformComponent() {
  if [[ ${databaseType} == "MySQL" ]];then
    if [[ ${outsideMysql} == 1 ]];then
      mysqlIp=${mysqlServiceIp}
    else
      mysqlIp=${hostIp}
    fi
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    if [[ ${release} == "standard" ]];then
      ##标准版需要加权限白名单
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlIp} -P${mysqlhostport} < ${workdir}other/addStandardPermissionBlack.sql >> ${logFile} 2>&1
    fi
    if [[ ${release} == "enterprise" && ${oldRelease} == "standard" ]];then
      ##企业版需要删除权限白名单
      ${mysqlAddr} -uroot -p${__mysqlRootPwd} -h${mysqlIp} -P${mysqlhostport} < ${workdir}other/deleteStandardPermissionBlack.sql >> ${logFile} 2>&1
    fi
  else
     if [[ ${installNodeType} == "OneNode" ]]; then
      password=($( __readINI zcloud.cfg single "mogdb.password" ))
      port=($( __readINI zcloud.cfg single "mogdb.port" ))
      user=($( __readINI zcloud.cfg single "mogdb.user" ))
      mogdbIp=($( __readINI zcloud.cfg single "mogdb.service.ip" ))
      dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
    else
      password=($( __readINI zcloud.cfg multiple "mogdb.password" ))
      port=($( __readINI zcloud.cfg multiple "mogdb.port" ))
      user=($( __readINI zcloud.cfg multiple "mogdb.user" ))
      mogdbIp=($( __readINI zcloud.cfg multiple "mogdb.service.ip" ))
      dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
    fi
    if [[ ${release} == "standard" ]];then
      export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${mogdbIp} -p ${port} -U ${user} -W ${password} -f ${workdir}other/addStandardPermissionBlack.sql
    fi
    if [[ ${release} == "enterprise" && ${oldRelease} == "standard" ]];then
      export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${mogdbIp} -p ${port} -U ${user} -W ${password} -f ${workdir}other/deleteStandardPermissionBlack.sql
    fi
  fi

}

function __AndMySQLStartSh() {
      localip=${hostIp}
      homedir=`cd ~ && pwd`
      cd ${homedir}
      info "创建mysql启动服务文件文件成功，文件：${installPath}/keeper/script/mysqlstart.sh"
      echo "#!/bin/bash
MYSQL_PID=\$(ps -ef | grep 'mysqld_safe' | grep -v grep | awk '{print \$2}')
MYSQL_FILE=\$(ls ${installPath}/soft/mysql/mysql/bin/| grep 'mysqld_safe' | awk '{print \$1}')
#如果存在该文件并且没有进程
if [[ -z \$MYSQL_FILE ]]; then
    echo 'Can not find mysqld_safe file!'
else
    if [[  -z \$MYSQL_PID ]]; then
    echo 'Ready to start '\${MYSQL_FILE}
    ${installPath}/soft/mysql/mysql/bin/mysqld_safe --defaults-file=${installPath}/soft/mysql/conf/my.cnf --user=zcloud &
    echo '${installPath}/soft/mysql/mysql/bin/mysqld_safe --defaults-file=${installPath}/soft/mysql/conf/my.cnf --user=zcloud &'
    else
      echo 'MySQL running!'
    fi
fi
" > ${installPath}/keeper/script/mysqlstart.sh
chmod +x ${installPath}/keeper/script/mysqlstart.sh
}