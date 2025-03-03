#!/bin/bash

function __InstallMogDBAll {
  if [[  $( __readINI nodeconfig/current.cfg service mogdb ) == ${nodeNum} ]]; then
    if [[ ${installType} = "1" ]];then
      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
      fi
      if [[ ${dependenceOutside} = "1" ]];then
        info "MogDB为外部依赖，无需安装"
        info "安装MogDB客户端..."
        if [[ ! -e ${installPath}/soft/mogdb/app ]];then
          __CreateDir ${installPath}/soft/mogdb/app
          chown zcloud:zcloud ${installPath}/soft
        fi
        if [[ ${osType}  = "Kylin_x86"  ]];then
          tar -xvf soft/mogdb/client_kylin.tar.gz -C"soft/mogdb"
        else
          tar -xvf soft/mogdb/client.tar.gz -C"soft/mogdb"
        fi

        \cp -rf soft/mogdb/client/* ${installPath}/soft/mogdb/app
        chown -R zcloud:zcloud ${installPath}/soft/mogdb/app
      else
        if [[ `ptk ls|wc -l` -gt 2 ]];then
          if [[  `ps -ef|grep ${installPath}/soft/mogdb|grep -v grep |wc -l ` -eq 0 ]];then
            error "MogDB已安装，但未启动，请手动启动MogDB"
            exit 1
          else
            __UpgradeMogDB
          fi
        else
          __PTKInstallPrepare

          __InstallPTK

          __InstallMogDB
        fi
      fi

    else
      __UpgradeMogDB
    fi
  else
    info "当前节点无需安装MogDB"
  fi

}

function __UpgradeMogDB {
  if [[  `ptk cluster -n zcloud_cluster  status|grep database_version|grep '5.0.7'|wc -l` -gt 0 ]];then
    if [[ `ptk ls|grep 'upgrading'|wc -l` -gt 0 ]];then
      error "MogDB数据库升级失败，请回滚后重新执行zCloud升级命令"
      error "回滚命令： ptk cluster -n zcloud_cluster upgrade-rollback"
      exit 1
    fi
    info "已安装MogDB，无需重复安装"
  elif [[ `ptk cluster -n zcloud_cluster  status|grep database_version|grep '3.0.2'|wc -l` -gt 0 ]]; then
    info "开始升级MogDB"
    __InstallPTK
    if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
      mogDbPackageName=MogDB-5.0.7-Kylin-arm64-all.tar.gz
    elif [[ ${osType}  = "Kylin_x86" || `echo $osVersion|grep "8." |wc -l` > 0 ]]; then
      mogDbPackageName=MogDB-5.0.7-Kylin-x86_64-all.tar.gz
    else
      mogDbPackageName=MogDB-5.0.7-CentOS-x86_64-all.tar.gz
    fi
    ptk cluster -n zcloud_cluster upgrade -y -p ${workdir}/soft/mogdb/${mogDbPackageName} -H ${hostIp}
    ptk cluster -n zcloud_cluster upgrade-commit
  fi

}

#PTK 安装前置准备
function __PTKInstallPrepare {
  __InstallMogDBDependence
  info "安装python.."
  __InstallPython
  info "关闭SELinux.."
  __CloseSeLinux
  info "修改profile.."
  __ModifyEvnProfile
  info "检查网卡配置.."
  __CheckIfconfigMTU
  info "关闭透明大页.."
  __CloseHugepage
  info "关闭ReMoveIPC.."
  __CloseRemoveIPC
  info "设置root用户远程登陆"
  __setSshConfig
  info "设置OS内核参数"
  __ModifyOsKernelParam
}

#安装PTK
function __InstallPTK {
  if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm"  ]];then
    tar -zxf soft/ptk/ptk_1.4.5_linux_arm64.tar.gz -C"soft/ptk"
    \cp -f soft/ptk/ptk /usr/bin
  else
    tar -zxf soft/ptk/ptk_1.4.5_linux_x86_64.tar.gz -C"soft/ptk"
    \cp -f soft/ptk/ptk /usr/bin
  fi
  chmod 755 /usr/bin/ptk
  info "安装PTK成功"
}

#安装MogDB
function __InstallMogDB {
  if [[  $( __readINI nodeconfig/current.cfg service mogdb ) == ${nodeNum} ]]; then
    info "安装MogDB.."
    if [[ `ptk ls|wc -l` -gt 2 ]];then
      if [[  `ps -ef|grep ${installPath}/soft/mogdb|grep -v grep |wc -l ` -eq 0 ]];then
        error "MogDB已安装，但未启动，请手动启动MogDB"
        exit 1
      else
        info "已安装MogDB，无需重复安装"
      fi
    else
      if [[ ! -f /usr/lib64/libssl.so.10 && ! -f /usr/lib64/libssl.so.1.0.2k  ]];then
        cp ${workdir}/soft/mogdb/libssl.so.1.0.2k /usr/lib64/
        cd /usr/lib64/
        ln -s libssl.so.1.0.2k libssl.so.10
      fi

      if [[ ! -f /usr/lib64/libcrypto.so.10 && ! -f /usr/lib64/libcrypto.so.1.0.2k  ]];then
        cp ${workdir}/soft/mogdb/libcrypto.so.1.0.2k /usr/lib64/
        cd /usr/lib64/
        ln -s libcrypto.so.1.0.2k libcrypto.so.10
      fi
      cd ${workdir}

      if [[ ${installNodeType} == "OneNode" ]]; then
        password=($( __readINI zcloud.cfg single "mogdb.password" ))
        port=($( __readINI zcloud.cfg single "mogdb.port" ))
        user=($( __readINI zcloud.cfg single "mogdb.user" ))
      else
        password=($( __readINI zcloud.cfg multiple "mogdb.password" ))
        port=($( __readINI zcloud.cfg multiple "mogdb.port" ))
        user=($( __readINI zcloud.cfg multiple "mogdb.user" ))
      fi
      if [[ `ss -tlnp|awk '{print $4}' | grep ${port}|wc -l` -gt 0 ]];then
        error "端口${port},被占用，安装MogDB失败"
        exit 1
      fi
      dbPassword=`ptk encrypt ${password}|awk -F':' '{print $NF}'`
      __CreateDir ${installPath}/soft/mogdb
      chown zcloud:zcloud ${installPath}/soft
      \cp -f conf/mogdb/config.yaml ${installPath}/soft/mogdb
      configPath=${installPath}/soft/mogdb/config.yaml
      sed -i "s|#baseDir#|${installPath}/soft/mogdb|g" ${configPath}
      sed -i "s|#dbPassword#|${dbPassword}|g" ${configPath}
      sed -i "s|#dbPort#|${port}|g" ${configPath}
      ptk checkos -f ${configPath}
      if [[ $(echo `ptk checkos -i A15 --detail` |grep -i ERROR|wc -l) -gt 2 ]];then
        error "MogDB安装配置错误，请使用 ptk checkos -i A15 --detail查看错误详情"
        exit 1
      fi
      if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
        mogDbPackageName=MogDB-5.0.7-Kylin-arm64-all.tar.gz
      elif [[ ${osType}  = "Kylin_x86" || ${osType}  = "bcLinux_x86" || `echo $osVersion|grep "8." |wc -l` > 0 ]]; then
        mogDbPackageName=MogDB-5.0.7-Kylin-x86_64-all.tar.gz
      else
        mogDbPackageName=MogDB-5.0.7-CentOS-x86_64-all.tar.gz
      fi
      ptk install -f ${configPath} --pkg soft/mogdb/${mogDbPackageName} --skip-check-os --skip-create-user -y
      if [[ `ptk ls|wc -l` -gt 2 ]];then
        info "MogDB安装成功"
      else
        error "MogDB安装失败"
        exit 1
      fi
      cp dbsqlfile/mogdb/init_database.sql dbsqlfile/mogdb/init_database_install.sql
      chown zcloud:zcloud dbsqlfile/mogdb/init_database_install.sql
      sed -i "s/#user#/${user}/g" dbsqlfile/mogdb/init_database_install.sql
      sed -i "s/#password#/'${password}'/g" dbsqlfile/mogdb/init_database_install.sql
      export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
      #export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib:$LD_LIBRARY_PATH
      #echo  ${LD_LIBRARY_PATH}
      echo "su - zcloud -c\"${installPath}/soft/mogdb/app/bin/gsql -f ${workdir}/dbsqlfile/mogdb/init_database_install.sql\""
      su - zcloud -c"${installPath}/soft/mogdb/app/bin/gsql -f ${workdir}/dbsqlfile/mogdb/init_database_install.sql"
      filePath=${installPath}/soft/mogdb/data/pg_hba.conf
      if [[ $(egrep 'host all ${user} 0.0.0.0/0 sha256' ${filePath}|wc -l) = 0 ]];then
        echo "host all ${user} 0.0.0.0/0 sha256">>${filePath}
      fi
      su - zcloud -c"${installPath}/soft/mogdb/app/bin/gs_ctl -D ${installPath}/soft/mogdb/data reload"


    fi
    \cp -f script/other/start.sh ${installPath}/soft/mogdb
    \cp -f script/other/stop.sh ${installPath}/soft/mogdb
    chown zcloud:zcloud  ${installPath}/soft/mogdb/start.sh
    chown zcloud:zcloud  ${installPath}/soft/mogdb/stop.sh
  else
    info "当前节点无需安裝MogDB"
  fi
}

function __InitMogDBData {
  if [[  $( __readINI nodeconfig/current.cfg service mogdb ) == ${nodeNum} ]]; then

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
    export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
    if [[ ${installType} = "1" ]];then
      if [[ ${dependenceOutside} = "1" ]];then
        export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
        ip=${mogdbIp}

      else
        if [[ $( __ReadValue ${logPath}/evn.cfg initedMogdb) = "" ]];then
          ip=${hostIp}
          ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f dbsqlfile/mogdb/clear.sql
          ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f dbsqlfile/mogdb/zcloud_full.sql
          __ReplaceText ${logPath}/evn.cfg "initedMogdb=" "initedMogdb=1"
          ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
          sed -i "s/#zcloud_ip_addr_port#/${hostIp}:${ui_url_port}/g" dbsqlfile/mogdb/update.sql
          sed -i "s/#gateway_ip_addr#/${hostIp}:${ui_url_port}/g" dbsqlfile/mogdb/update.sql
          sed -i "s/#monitor_ip_addr#/${hostIp}/g" dbsqlfile/mogdb/update.sql
          info "${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f dbsqlfile/mogdb/update.sql"
          ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f dbsqlfile/mogdb/update.sql
        else
          echo "MogDB数据已初始化, 无需重新初始化"
        fi


      fi

    else
      info "升級无需执行此步骤"
    fi

    if [[ ${dependenceOutside} = "1" ]];then
      export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
      ip=${mogdbIp}
    else
      ip=${hostIp}
    fi
    if [[ ${release} == "standard" ]];then
      ##标准版需要加权限白名单
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f ${workdir}other/addStandardPermissionBlack.sql
    else
      ##企业版需要删除权限白名单
      info "${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f ${workdir}other/deleteStandardPermissionBlack.sql"
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f ${workdir}other/deleteStandardPermissionBlack.sql
    fi

  else
    info "当前节点无需初始化MogDB数据"
  fi
  info "安装MogDB客户端..."
  if [[ ! -e ${installPath}/soft/mogdb/app ]];then
    __CreateDir ${installPath}/soft/mogdb/app
    chown zcloud:zcloud ${installPath}/soft
    if [[ ${osType}  = "Kylin_x86"  ]];then
      tar -xvf soft/mogdb/client_kylin.tar.gz -C"soft/mogdb"
    else
      tar -xvf soft/mogdb/client.tar.gz -C"soft/mogdb"
    fi

    \cp -rf soft/mogdb/client/* ${installPath}/soft/mogdb/app
    chown -R zcloud:zcloud ${installPath}/soft/mogdb/app

  fi

  if [[ ${installNodeType} == "OneNode" ]]; then
    if [[ ${dependenceOutside} = "1" ]];then
      serviceIp=$(__readINI ${zcloudCfg} single mogdb.service.ip)
    else
      serviceIp=${hostIp}
    fi
    port=$(__readINI ${zcloudCfg} single mogdb.port)
    password=$(__readINI ${zcloudCfg} single mogdb.password)
    user=$(__readINI ${zcloudCfg} single mogdb.user)
  else
    serviceIp=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
    port=$(__readINI ${zcloudCfg} multiple mogdb.port)
    password=$(__readINI ${zcloudCfg} multiple mogdb.password)
    user=$(__readINI ${zcloudCfg} multiple mogdb.user)
  fi
  ip=${serviceIp}
  export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
  if [[ ${release} == "standard" ]];then
    ##标准版需要禁用 扫描智能指标模板和训练智能指标 定时任务
    info "execute updateAiAlertTask_standard_mogdb.sql"
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f ${workdir}other/updateAiAlertTask_standard_mogdb.sql
  else
    ##非标准版需要启用 扫描智能指标模板和训练智能指标 定时任务
    info "execute updateAiAlertTask_mogdb.sql"
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${ip} -p ${port} -U ${user} -W ${password} -f ${workdir}other/updateAiAlertTask_mogdb.sql
  fi
}

function __InstallMogDBDependence {
  info "安装MogDB需要的依赖.."
  linux_kernel_version=$(uname -r|awk -F'\\.' '{print $1}')
  if [[ ${osType}  == "Kylin_arm" || ${osType}  == "Kylin_x86" ]];then
    if [ $linux_kernel_version -ge 4 ];then
      yum -y --nobest install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect ${repoCommand}
    else
      yum -y install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect ${repoCommand}
    fi
    for softName in zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect
    do
      info "yum list ${softName} ${repoCommand}"
      result=`yum list ${softName} ${repoCommand}`
      info "${result}"
    done
  elif [[ ${osType}  == "uos_arm" || ${osType}  == "uos_x86" ]];then
    if [ $linux_kernel_version -ge 4 ];then
          yum -y --nobest install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect ${repoCommand}
        else
          yum -y install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect ${repoCommand}
        fi
        for softName in zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect
        do
          info "yum list ${softName} ${repoCommand}"
          result=`yum list ${softName} ${repoCommand}`
          info "${result}"
        done
  elif [[ ${osType}  == "openEuler_arm" || ${osType}  == "openEuler_x86" || ${osType}  == "bcLinux_arm" || ${osType}  == "bcLinux_x86" ]];then
    if [ $linux_kernel_version -ge 4 ];then
          yum -y --nobest install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect ${repoCommand}
        else
          yum -y install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect ${repoCommand}
        fi
        for softName in zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make xz-devel libffi-devel  expect
        do
          info "yum list ${softName} ${repoCommand}"
          result=`yum list ${softName} ${repoCommand}`
          info "${result}"
        done
  else
    if [ $linux_kernel_version -ge 4 ];then
      yum -y --nobest install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make gdbm-devel xz-devel libffi-devel  expect ${repoCommand}
    else
      yum -y install zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make gdbm-devel xz-devel libffi-devel  expect ${repoCommand}
    fi
    for softName in zlib-devel net-tools lsof numactl bzip2 bzip2-devel libaio-devel openssh bison flex psmisc openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make gdbm-devel xz-devel libffi-devel  expect
    do
      info "yum list ${softName} ${repoCommand}"
      result=`yum list ${softName} ${repoCommand}`
      info "${result}"
    done
  fi
}

function __InstallPython {
  if [[ ${osType}  = "Kylin_arm" || ${osType}  = "Kylin_x86" || ${osType}  = "uos_arm" || ${osType}  = "uos_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "openEuler_x86"
  || ${osType}  = "bcLinux_arm" || ${osType}  = "bcLinux_x86" ]];then
    pythonInstallVersion=3.7
  else
    pythonInstallVersion=3.6
  fi
  set +e
    versionV=`python3 -V`>>${logFile}
    code=$?
  set -e
  if [[ ${code} != "0" ]];then
    tar -zxf soft/python/Python-${pythonInstallVersion}.15.tgz -C"soft/python"
    mkdir -p /usr/local/Python3
    chmod 755 /usr/local/Python3
    cd soft/python/Python-${pythonInstallVersion}.15
    ./configure --prefix=/usr/local/Python3 --enable-shared
    make
    make install
    ln -s /usr/local/Python3/bin/python3 /usr/bin/python3
    ln -s /usr/local/Python3/bin/pip3 /usr/bin/pip3
    cd ${workdir}
    if [[ ! -f /usr/lib64/libpython${pythonInstallVersion}m.so.1.0 ]];then
      cp soft/python/Python-${pythonInstallVersion}.15/libpython${pythonInstallVersion}m.so.1.0 /usr/lib64
    fi
  else
    if [[ `echo ${versionV}|awk '{print $NF}'` =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
    then
        pythonVersion=${BASH_REMATCH[1]}
        pythonVersion_part1=${BASH_REMATCH[2]}
        pythonVersion_part2=${BASH_REMATCH[3]}
        info "python version: ${pythonVersion}"
        version=${pythonVersion_part1}.${pythonVersion_part2}
        if [[ ${version} = ${pythonInstallVersion} ]];then
          if [[ `python3 -m sysconfig|grep -i "py_enable_shared"|awk '{print $NF}'` = "\"1\"" ]];then
            info "已安装python，无需重复安装"
          else
            error "编译安装python${pythonInstallVersion}的时候没有使用 --enable-shared，请卸载原有的python${pythonInstallVersion}, 重新安装"
            exit 1
          fi
        fi

    else
        info "Failed to parse python version."
        exit 1
    fi
  fi
}

function __CloseSeLinux {
  seLinuxConfigPath="/etc/selinux/config"
  if [[ $(egrep '(^SELINUX=)(.*)' ${seLinuxConfigPath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^SELINUX=)(.*)/\1disabled/g" ${seLinuxConfigPath}
  else
    echo "SELINUX=disabled">>${seLinuxConfigPath}
  fi
  set +e
  setenforce 0
  set -e
}

function __ModifyEvnProfile {
  profilePath="/etc/profile"
  if [[ $(egrep '(^export LANG=)(.*)' ${profilePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^export LANG=)(.*)/\1en_US.UTF-8/g" ${profilePath}
  else
    echo "export LANG=en_US.UTF-8">>${profilePath}
  fi
  set +e
  source ${profilePath} || true
  set -e
  if [[ ${osType}  = "uos_arm" ]];then
      source ${profilePath} || true
    else
      source ${profilePath} || true
  fi
}

function __CheckIfconfigMTU {
  for mtu in `ifconfig|grep mtu|awk '{print $NF}'`
  do
    if [[ ${mtu} -lt 1500 ]];then
      error "网卡的MTU值值小于1500，当前MTU值${mtu}"
      exit 1
    fi
  done
}

#关闭透明大页
function __CloseHugepage {
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
}

#关闭ReMoveIPC
function __CloseRemoveIPC() {
  filePath=/etc/systemd/logind.conf
  if [[ $(egrep '(^RemoveIPC=)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^RemoveIPC=)(.*)/\1no/g" ${filePath}
  else
    echo "RemoveIPC=no">>${filePath}
  fi

  filePath=/usr/lib/systemd/system/systemd-logind.service
  if [[ $(egrep '(^RemoveIPC=)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^RemoveIPC=)(.*)/\1no/g" ${filePath}
  else
    echo "RemoveIPC=no">>${filePath}
  fi
  systemctl daemon-reload
  systemctl restart systemd-logind

}

function __setSshConfig {
  filePath=/etc/ssh/sshd_config
  if [[ $(egrep '(^PermitRootLogin\s+)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^PermitRootLogin\s+)(.*)/\1yes/g" ${filePath}
  else
    echo "PermitRootLogin=yes">>${filePath}
  fi
  if [[ $(egrep '(^Banner)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/Banner/#Banner/g" ${filePath}
  fi
  systemctl restart sshd
}

function __ModifyOsKernelParam {
  filePath=/etc/sysctl.conf
  if [[ $(egrep '(^net.ipv4.tcp_timestamps\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_timestamps\s*=\s*)(.*)/\11/g" ${filePath}
  else
    echo "net.ipv4.tcp_timestamps = 1">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_mem\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_mem\s*=\s*)(.*)/\194500000 915000000 927000000/g" ${filePath}
  else
    echo "net.ipv4.tcp_mem = 94500000 915000000 927000000">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_max_orphans\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_max_orphans\s*=\s*)(.*)/\13276800/g" ${filePath}
  else
    echo "net.ipv4.tcp_max_orphans = 3276800">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_fin_timeout\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_fin_timeout\s*=\s*)(.*)/\160/g" ${filePath}
  else
    echo "net.ipv4.tcp_fin_timeout = 60">>${filePath}
  fi

  if [[ $(egrep '(^net.ipv4.ip_local_port_range\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.ip_local_port_range\s*=\s*)(.*)/\126000 65535/g" ${filePath}
  else
    echo "net.ipv4.ip_local_port_range = 26000 65535">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_keepalive_intvl\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_keepalive_intvl\s*=\s*)(.*)/\130/g" ${filePath}
  else
    echo "net.ipv4.tcp_keepalive_intvl = 30">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_max_syn_backlog\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_max_syn_backlog\s*=\s*)(.*)/\165535/g" ${filePath}
  else
    echo "net.ipv4.tcp_max_syn_backlog = 65535">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_syn_retries\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_syn_retries\s*=\s*)(.*)/\15/g" ${filePath}
  else
    echo "net.ipv4.tcp_syn_retries = 5">>${filePath}
  fi

  if [[ $(egrep '(^net.core.somaxconn\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.core.somaxconn\s*=\s*)(.*)/\165535/g" ${filePath}
  else
    echo "net.core.somaxconn = 65535">>${filePath}
  fi

  if [[ $(egrep '(^net.ipv4.tcp_retries1\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_retries1\s*=\s*)(.*)/\15/g" ${filePath}
  else
    echo "net.ipv4.tcp_retries1 = 5">>${filePath}
  fi

  if [[ $(egrep '(^net.core.wmem_max\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.core.wmem_max\s*=\s*)(.*)/\121299200/g" ${filePath}
  else
    echo "net.core.wmem_max = 21299200">>${filePath}
  fi
  if [[ $(egrep '(^net.core.rmem_max\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.core.rmem_max\s*=\s*)(.*)/\121299200/g" ${filePath}
  else
    echo "net.core.rmem_max = 21299200">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_keepalive_time\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_keepalive_time\s*=\s*)(.*)/\130/g" ${filePath}
  else
    echo "net.ipv4.tcp_keepalive_time = 30">>${filePath}
  fi
  if [[ $(egrep '(^net.core.wmem_default\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.core.wmem_default\s*=\s*)(.*)/\121299200/g" ${filePath}
  else
    echo "net.core.wmem_default = 21299200">>${filePath}
  fi
  if [[ $(egrep '(^net.core.rmem_default\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.core.rmem_default\s*=\s*)(.*)/\121299200/g" ${filePath}
  else
    echo "net.core.rmem_default = 21299200">>${filePath}
  fi
  if [[ $(egrep '(^net.core.netdev_max_backlog\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.core.netdev_max_backlog\s*=\s*)(.*)/\165535/g" ${filePath}
  else
    echo "net.core.netdev_max_backlog = 65535">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_syncookies\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_syncookies\s*=\s*)(.*)/\11/g" ${filePath}
  else
    echo "net.ipv4.tcp_syncookies = 1">>${filePath}
  fi

  if [[ $(egrep '(^net.ipv4.tcp_retries2\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_retries2\s*=\s*)(.*)/\112/g" ${filePath}
  else
    echo "net.ipv4.tcp_retries2 = 12">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_rmem\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_rmem\s*=\s*)(.*)/\18192 250000 16777216/g" ${filePath}
  else
    echo "net.ipv4.tcp_rmem = 8192 250000 16777216">>${filePath}
  fi
  if [[ $(egrep '(^net.ipv4.tcp_wmem\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^net.ipv4.tcp_wmem\s*=\s*)(.*)/\18192 250000 16777216/g" ${filePath}
  else
    echo "net.ipv4.tcp_wmem = 8192 250000 16777216">>${filePath}
  fi
  if [[ $(egrep '(^kernel.sem\s*=\s*)(.*)' ${filePath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^kernel.sem\s*=\s*)(.*)/\1250 6400000 1000 25600/g" ${filePath}
  else
    echo "kernel.sem = 250 6400000 1000 25600">>${filePath}
  fi
  set +e
  sysctl -p
  set -e

}


function __updateMogDBComponentIp {
  if [[ ! -e ${installPath}/soft/mogdb/app/bin ]];then
    __CreateDir ${installPath}/soft/mogdb/app
    chown zcloud:zcloud ${installPath}/soft
    if [[ ${osType}  = "Kylin_x86"  ]];then
      tar -xvf soft/mogdb/client_kylin.tar.gz -C"soft/mogdb"
    else
      tar -xvf soft/mogdb/client.tar.gz -C"soft/mogdb"
    fi
    \cp -rf soft/mogdb/client/* ${installPath}/soft/mogdb/app
  fi

  echo "" >  other/updateAfterMysqlInstall.sql
  echo "SET search_path to monitormanager;" >> other/updateAfterMysqlInstall.sql
  localIp=$( __ReadValue nodeconfig/installparam.txt hostIp)
  info "当前节点配置ip ${localIp}"

    zcloudCfg=${workdir}/zcloud.cfg
    if [[ ${installNodeType} == "OneNode" ]]; then
      dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
    else
      dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
    fi
    if [[ ${installNodeType} == "OneNode" ]]; then
      if [[ ${dependenceOutside} = "1" ]];then
        serviceIp=$(__readINI ${zcloudCfg} single mogdb.service.ip)
      else
        serviceIp=${hostIp}
      fi
      port=$(__readINI ${zcloudCfg} single mogdb.port)
      password=$(__readINI ${zcloudCfg} single mogdb.password)
      user=$(__readINI ${zcloudCfg} single mogdb.user)
    else
      serviceIp=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
      port=$(__readINI ${zcloudCfg} multiple mogdb.port)
      password=$(__readINI ${zcloudCfg} multiple mogdb.password)
      user=$(__readINI ${zcloudCfg} multiple mogdb.user)
    fi

  #如果当前节点是配置数
  agentNum=$( __readINI nodeconfig/current.cfg service agent)
  info "agent 配置信息 ${agentNum}"
  export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib
  if [[ 1 == ${nodeNum} ]];then
      if [[ ${release} == "enterprise" ]];then
        ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${serviceIp} -p ${port} -U ${user} -W ${password} -f other/addComponent.sql >> ${logFile} 2>&1
      fi

      echo "DELETE FROM monitormanager.zcloud_platform_host;" >> other/updateAfterMysqlInstall.sql
      echo "INSERT INTO monitormanager.zcloud_platform_host (host_ip, host_port, host_type, install_dir, description) VALUES('${localIp}', 8100, 'Application', '${installPath}/agent/agent', '微服务');" >> other/updateAfterMysqlInstall.sql
    else
      echo "INSERT INTO monitormanager.zcloud_platform_host (host_ip, host_port, host_type, install_dir, description) VALUES('${localIp}', 8100, 'Application', '${installPath}/agent/agent', '微服务');" >> other/updateAfterMysqlInstall.sql
    fi
  if [[ ${agentNum} == ${nodeNum} ]];then
    echo "update zcloud_platform_host set host_ip='${localIp}', host_port='8100' ,install_dir='${homePath}/dbaas/soft-install/agent/agent';" >> other/updateAfterMysqlInstall.sql
  fi


    #update service
    for service in "dbaas-common-db" "dbaas-backend-script" "dbaas-backend-sql-server" "dbaas-datachange-management" "dbaas-monitor" "dbaas-monitor-dashboard" "dbaas-api-create-dg" "dbaas-configuration" "dbaas-mariadb" "dbaas-db-manage" "dbaas-create-postgres" "dbaas-create-redis" "dbaas-create-shardingsphere" "dbaas-apigateway" "dbaas-infrastructure" "dbaas-operate-db" "dbaas-permissions" "dbaas-reposerver" "task-management" "dbaas-backend-db2" "dbaas-create-mongodb" "dbaas-database-snapshot" "dbaas-backend-damengdb" "dbaas-backend-mogdb" "dbaas-backend-oceanbase" "dbaas-ogg-management" "dbaas-flyway-manage" "dbaas-common-backupcenter" "dbaas-doc-retrieval" "dbaas-lowcode-atomic-ability" "dbaas-management-database" "dbaas-management-host" "expert-knowledge-base" "zdbmon-mgr";do
      serviceNum=$( __readINI nodeconfig/current.cfg service ${service})
      if [[ ${serviceNum} == ${nodeNum} ]];then
        echo "update zcloud_platform_component set ip='${localIp}' where name = '${service}';" >> other/updateAfterMysqlInstall.sql
      fi
    done

    info "配置updateAfterMysqlInstall.sql完成"


    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${serviceIp} -p ${port} -U ${user} -W ${password} -f other/updateAfterMysqlInstall.sql >> ${logFile} 2>&1
    info "更新组件ip成功"
}













