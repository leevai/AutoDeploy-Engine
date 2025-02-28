installBasePath=#{install_path}
__mysqlRootPwd=#{mysql_password}
installPath=${installBasePath}/mysql

function __InstallMySQLCommon {
    info "开始安装MySQL "
    info "此步骤大概需要执行1m,请等待"
    __CreateDir ${installPath}/soft/mysql/soft
    __CreateDir ${installPath}/soft/mysql/data
    __CreateDir ${installPath}/soft/mysql/conf
    if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
      tar -zxf ./services/mysql/mysql-5.7.34-kylin-aarch64.tar.gz -C "${installPath}/soft/mysql/"
    else
      tar -zxf ./services/mysql/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz -C "${installPath}/soft/mysql/"
      mv ${installPath}/soft/mysql/mysql-5.7.38-linux-glibc2.12-x86_64 ${installPath}/soft/mysql/mysql
    fi
#    cd ${workdir}
#    cp script/other/start.sh ${installPath}/soft/mysql
#    cp script/other/stop.sh ${installPath}/soft/mysql

#    if [[ ${installType} = 2 ]];then
#      bakTimePath=($( __ReadValue ${logPath}/evn.cfg bakTimePath))
#      \cp -f ${bakTimePath}/my.cnf  ${installPath}/soft/mysql/conf/
#    else
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
#    fi
    #配置环境变量
#    homedir=`cd ~ && pwd`
#    if [[ ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  ) && ${osVersion} == 8.* ]]; then
#          if [[ $(egrep "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" ${homedir}/.bashrc|wc -l) -eq 0 ]];then
#              echo "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" >> ${homedir}/.bashrc
#              echo "export PATH CLASSPATH JAVA_HOME" >> ${homedir}/.bashrc
#          fi
#    else
#    __ReplaceText ${homedir}/.bashrc "PATH=" "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin"
#    __ReplaceText ${homedir}/.bashrc "export" "export PATH CLASSPATH JAVA_HOME"
#    fi
#    source ${homedir}/.bashrc || true
}

function __InstallMySQLNonRoot {
    __InstallMySQLCommon
    ${installPath}/soft/mysql/mysql/bin/mysqld --defaults-file=${installPath}/soft/mysql/conf/my.cnf --initialize-insecure --user=root
    sleep 10
    ${installPath}/soft/mysql/mysql/bin/mysqld_safe --defaults-file=${installPath}/soft/mysql/conf/my.cnf --user=root > /dev/null 2>&1 &
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
    exit 0
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

function __CreateDir() {
  filePath=$1
  if [[ ! -e $filePath ]]; then
    mkdir -p "${filePath}";
    info "创建文件夹成功，文件夹路径:${filePath}";
  else
    info "创建文件夹已存在，文件夹路径:${filePath}";
  fi
}

function info() {
    printf "[zcloud dbaas] $@ \n"
}


__InstallMySQLNonRoot