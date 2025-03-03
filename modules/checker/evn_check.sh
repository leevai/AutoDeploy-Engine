#!/bin/bash
# 安装环境前置检查

# 获取操作系统版本
function __CheckOSVersion {
    startTime=$(date +"%s%N")
    str=`cat /etc/system-release`

    if [[ `echo $str | grep 'CentOS' | wc -l ` -gt 0 ]]; then
        osType=CentOS
        osVersion=`echo $str | awk '{print $(NF-1)}' | awk -F'.' '{print $1"."$2}'`
    elif [[ `echo $str | grep 'Red Hat' | wc -l ` -gt 0 ]]; then
        osType=RedHat
        osVersion=`echo $str | awk '{print $(NF-1)}' | awk -F'.' '{print $1"."$2}'`
    elif [[ `echo $str | grep 'Oracle' | wc -l ` -gt 0 ]]; then
        osType=Oracle
        osVersion=`echo $str | awk '{print $(NF)}' | awk -F'.' '{print $1"."$2}'`
    elif [[ `echo $str | grep 'Kylin' | wc -l ` -gt 0 ]]; then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="Kylin_x86"
        else
          osType="Kylin_arm"
        fi
        osVersion=`echo $str | awk '{print $(NF-1)}'`
    elif [[ `echo $str | grep 'uos' | wc -l ` -gt 0 ]];then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="uos_x86"
        else
          osType="uos_arm"
        fi
        osVersion=`echo $str | awk '{print $(NF-1)}'`
    elif [[ `echo $str | grep 'openEuler' | wc -l ` -gt 0 ]];then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="openEuler_x86"
        else
          osType="openEuler_arm"
        fi
        osVersion=`echo $str | grep -oP 'release \K[0-9]+\.[0-9]+' | awk -F'.' '{print $1}'`
    elif [[ `echo $str | grep 'BigCloud Enterprise Linux For Euler release' | wc -l ` -gt 0 || `echo $str | grep 'bclinux For Euler release' | wc -l ` -gt 0 ]];then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="bcLinux_x86"
        else
          osType="bcLinux_arm"
        fi
        osVersion=`echo $str | grep -oP 'release \K[0-9]+\.[0-9]+' | awk -F'.' '{print $1"."$2}'`
    else
      error "仅支持CentOS,Red Hat,Kylin,BC Linux for Euler上运行zCloud"
      exit 1
    fi
    info "当前主机的操作系统为$osType,操作系统版本为$osVersion"
    if [[ "CentOS" = $osType || "RedHat" = $osType  ]]; then
      if [[ $osVersion < '7.0' ]]; then
          error $osType+"版本应该大于7.0，当前版本为:"$osVersion
          exit 1
      fi
      if [[ $osVersion > '8.9' ]]; then
          error $osType+"版本只支持7.x 8.x，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "Oracle" = $osType ]];then
      if [[ $osVersion < '7.0' ]]; then
          error $osType+"版本应该大于7.0，当前版本为:"$osVersion
          exit 1
      fi
      if [[ $osVersion > '8.9' ]]; then
          error $osType+"版本只支持7.x，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "uos_x86" = $osType || "uos_arm" = $osType ]];then
      if [[ $osVersion -ne "20" ]];then
          error $osType+"版本应该等于20，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "openEuler_x86" = $osType || "openEuler_arm" = $osType ]];then
      if [[ $osVersion -gt 22 || $osVersion -lt  20 ]];then
          error $osType+"版本支持20-22，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "bcLinux_x86" = $osType || "bcLinux_arm" = $osType ]];then
      if [[ $osVersion != 22.10 && $osVersion != 21.10 ]];then
          error $osType+"版本支持21.10-22.10，当前版本为:"$osVersion
          exit 1
      fi
    else
      if [[ $osVersion -ne "V10" ]]; then
          error $osType+"版本应该等于V10，当前版本为:"$osVersion
          exit 1
      fi
    fi
    __ReplaceText ${logPath}/evn.cfg "osType=" "osType=${osType}"
    __ReplaceText ${logPath}/evn.cfg "osVersion=" "osVersion=${osVersion}"
    endTime=$(date +"%s%N")
    info "检查操作系统版本完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckZDataXOSVersion {
    startTime=$(date +"%s%N")
    str=`cat /etc/system-release`
    cpuStructure="x86"
    if [[ -f cpu_structure.txt ]];then
      cpuStructure=`cat cpu_structure.txt`
    fi
    if [[ ${cpuStructure} == "x86" ]];then
      if [[ `echo $str | grep 'Oracle' | wc -l ` -gt 0 ]];then
          osType="Oracle"
          osVersion=`echo $str | awk '{print $(NF)}'`
          if [[ `uname -i` != "x86_64" ]];then
            error "仅支持Oracle Linux x86_64 架构上运行zCloud"
            exit 1
          fi
      elif [[ `echo $str | grep 'Kylin' | wc -l ` -gt 0 ]];then
        osType="Kylin_x86"
        osVersion=`echo $str | awk '{print $(NF)}'`
        if [[ `uname -i` != "x86_64" ]];then
          error "仅支持Kylin Linux x86_64 架构上运行zCloud"
          exit 1
        fi
      else
        error "仅支持Oracle Linux x86_64 架构上运行zCloud"
        exit 1
      fi
      info "当前主机的操作系统为$osType,操作系统版本为$osVersion"
      if [[ "Oracle" = $osType ]]; then
        if [[ $osVersion != '7.9' ]]; then
            error $osType" Linux版本只支持7.9，当前版本为:"$osVersion
            exit 1
        fi
      fi
    else
      if [[ `echo $str | grep 'Kylin' | wc -l ` -gt 0 ]];then
          osType="Kylin_arm"
          osVersion=`echo $str | awk '{print $(NF-1)}'`
          if [[ `uname -i` != "aarch64" ]];then
            error "仅支持Kylin Linux arm 架构上运行zCloud"
            exit 1
          fi
      else
        error "仅支持Kylin Linux arm 架构上运行zCloud"
        exit 1
      fi
      info "当前主机的操作系统为$osType,操作系统版本为$osVersion"
      if [[ "Kylin_arm" = $osType ]]; then
        if [[ $osVersion != 'V10' ]]; then
            error "Kylin Linux 版本只支持V10，当前版本为 "$osVersion
            exit 1
        fi
      fi
      osVersion2=`nkvers|grep SP|awk -F"(" '{print $2}'|awk -F")" '{print $1}'`
      if [[ ${osVersion2} != "SP2" ]];then
        error "Kylin Linux版本只支持V10 SP2，当前版本为 $osVersion $osVersion2"
        exit 1
      fi
    fi
    __ReplaceText ${logPath}/evn.cfg "osType=" "osType=${osType}"
    endTime=$(date +"%s%N")
    info "检查操作系统版本完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckInstallType {
  installPath="${homePath}/dbaas/soft-install"
  startTime=$(date +"%s%N")
  cd /usr/lib/systemd/system
  logPath=${homePath}/dbaas/zcloud-log
  if [[ -f ${logPath}/evn.cfg ]];then
    installType=($( __ReadValue ${logPath}/evn.cfg installType))
  fi
  if [[ ${installType} != "" ]];then
    info "installType = ${installType}"
    if [[ ${installType} = 1 ]];then
      info "zCloud安装类型为全新安装"
    elif [[ ${installType} = 2 ]];then
      info "zCloud安装类型为root升级为非root"
    else
     info "zCloud安装类型为标准安装升级"
    fi
  else
     serviceCount=$(ls |egrep "dbaas-api-create-dg.service$|dbaas-apigateway.service$|dbaas-backend-damengdb.service$|dbaas-backend-db2.service$|dbaas-backend-mogdb.service$|dbaas-backend-oceanbase.service$|dbaas-backend-script.service$|dbaas-backend-sql-server.service$|dbaas-common-db.service$|dbaas-configuration.service$|dbaas-create-mongodb.service$|dbaas-create-postgres.service$|dbaas-create-redis.service$|dbaas-create-shardingsphere.service$|dbaas-database-snapshot.service$|dbaas-datachange-management.service$|dbaas-db-manage.service$|dbaas-eureka-server.service$|dbaas-infrastructure.service$|dbaas-mariadb.service$|dbaas-monitor-dashboard.service$|dbaas-monitor.service$|dbaas-operate-db.service$|dbaas-permissions.service$|dbaas-reposerver.service$|ai-business.service$|zcloud-ai-adapter.service$|zcloud_altermanager.service$|zcloud_slowmon_mgr.service$|zcloud_zoramon_mgr.service$|zcloud_smart_baseline.service$|zcloud_registrationHub.service$|consul.service$|task-management.service$"|wc -l)
    info "${serviceCount}"
    if [[ ${serviceCount} -gt 0 ]];then
      installType=2
      info "zCloud安装类型为root升级为非root"
    elif [[ ! -e ${installPath} || `ls ${installPath}|wc -l` = 0 ]];then
      installType=1
      info "zCloud安装类型为全新安装"
      zCloudVersion=`ps -ef|grep dbaas-infrastructure|grep -v grep|awk '{print $(NF-4)}'|awk -F'/' '{print $NF}' |awk -F'-' '{print $(NF-1)}'`
    else
      installType=4
      info "zCloud安装类型为标准安装升级"
    fi
    __ReplaceText ${logPath}/evn.cfg "installType=" "installType=${installType}"
  fi
  cd ${workdir}
  endTime=$(date +"%s%N")
  info "检查zCloud安装类型完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}
# 配置防火墙
function __CheckFirewall {
  if [[ ${installType} != 4 ]];then
    if [[ `systemctl list-units --type=service --state=active|grep firewalld|wc -l` = 0 ]];then
      info "防火墙已关闭"
    else
      info "建议关闭防火墙，关闭防火墙命令： systemctl stop firewalld.service;systemctl disable firewalld.service"
      info "当前防火墙配置"
      fireWallRule=`firewall-cmd --list-all`
      info "${fireWallRule}"
      info "推荐开启防火墙配置以下zcloud需要的端口规则"
      info "
             public
              target: default
              icmp-block-inversion: no
              interfaces:
              sources:
              services: ssh dhcpv6-client
              ports:
              protocols:
              masquerade: no
              forward-ports:
              source-ports:
              icmp-blocks:
              rich rules:
                    rule family="ipv4" port port="8080" protocol="tcp" accept
                    rule family="ipv4" port port="8500" protocol="tcp" accept
                    rule family="ipv4" port port="8086" protocol="tcp" accept
                    rule family="ipv4" port port="8094" protocol="tcp" accept
                    rule family="ipv4" port port="8093" protocol="tcp" accept
                    rule family="ipv4" port port="8761" protocol="tcp" accept
"

    fi
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
}

# 查询磁盘空间容量
function __GetDiskCapacity {
  type=$1
  startTime=$(date +"%s%N")
  if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
    diskCapacity=($(__readINI zcloud.cfg common "disk.min.capacity"))
    diskCapacity=$[diskCapacity-1]
    if [[ $(df ${homePath}|awk NR==2'{print}' |awk '{print $2}') -lt $((${diskCapacity}*1024*1024)) && ${type} != "upgrade" ]];then
      read -p "安装zCloud时服务磁盘空间最少需要准备$[${diskCapacity}+1]G,当前磁盘空间为$(df -h ${homePath}|awk NR==2'{print}' |awk '{print $2}'),是否继续(yes/no)" readValue
      if [[ ${readValue} != "yes" ]];then
        error "本次安装退出"
        exit 1
      fi
    else
      info "主机的磁盘空间满足zcloud正常安装"
    fi

  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
  endTime=$(date +"%s%N")
  info "检查服务器磁盘容量完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckCpuCore {
  type=$1
  startTime=$(date +"%s%N")
  if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
    coreNum=`cat /proc/cpuinfo | grep 'processor'| wc -l`
    defaultCoreNum=($(__readINI nodeconfig/current.cfg service "cpu.core.min"))
    if [[ ${coreNum} -lt ${defaultCoreNum}  && ${type} != "upgrade" ]];then
      read -p "安装zCloud时服务器CPU核心数最少需要准备${defaultCoreNum},当前CPU核心数为${coreNum},是否继续(yes/no)" readValue
        if [[ ${readValue} != "yes" ]];then
          error "本次安装退出"
          exit 1
        fi
    fi
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
  endTime=$(date +"%s%N")
  info "检查服务器CPU核心数完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckMemory {
  type=$1
  startTime=$(date +"%s%N")
  if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
    memorySize=`free -h|grep Mem|awk '{print $2}'|sed -r "s/G$|Gi$//g"`
    defaultMemorySize=($(__readINI nodeconfig/current.cfg service "memory.min.size"))
    if [[ ${memorySize} -lt ${defaultMemorySize} && ${type} != "upgrade" ]];then
      read -p "安装zCloud时服务器内存最少需要准备${defaultMemorySize}G,当前内存为${memorySize}G,是否继续(yes/no)" readValue
        if [[ ${readValue} != "yes" ]];then
          error "本次安装退出"
          exit 1
        fi
    fi
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
  endTime=$(date +"%s%N")
  info "检查服务器内存完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

# yum安装依赖
function __InstallDependence {
  startTime=$(date +"%s%N")
  if [[ ${installType} != 4 ]];then
    info "yum安装依赖 ..."
    linux_kernel_version=$(uname -r|awk -F'\\.' '{print $1}')
    if [ $linux_kernel_version -ge 4 ];then
      yum -y --nobest install gcc-c++ gcc libxslt-devel gd gd-devel curl  libffi-devel ${repoCommand}
    else
      yum -y install gcc-c++ gcc libxslt-devel gd gd-devel curl  libffi-devel ${repoCommand}
    fi
    # openssl openssl-devel 可能会版本冲突，判断如果install了就不安装了
    set +e
    opensslStr=`openssl version`
    set -e
    if [[ `echo $opensslStr | grep 'OpenSSL' | wc -l ` -gt 0 ]]; then
      info "openssl already install"
    else
      info "start openssl install"
      yum -y  install openssl ${repoCommand}
    fi
    set +e
    opensslDevelStr=`rpm -q openssl-devel`
    set +e
    if [[ `echo $opensslDevelStr | grep 'openssl-devel' | wc -l ` -gt 0 ]]; then
        info "openssl-devel already install"
    else
        info "start openssl-devel install"
        yum -y  install openssl-devel ${repoCommand}
    fi
    #增加perl和perl-libs支持后续nginx编译
    set +e
    perlStr=`rpm -q perl`
    set -e
    if [[ `echo $perlStr | grep 'perl-' | wc -l ` -gt 0 ]]; then
        info "perl already install"
    else
        info "start perl install"
        yum -y  install perl ${repoCommand}
    fi
    set +e
    perlLibStr=`rpm -q perl-libs`
    set -e
    if [[ `echo $perlLibStr | grep 'perl-libs' | wc -l ` -gt 0 ]]; then
        info "perl-libs already install"
    else
        info "start perl-libs install"
        yum -y  install perl-libs ${repoCommand}
    fi

    if [[ ${osType} = "Kylin_arm" && ${theme} != "zData" ]];then
      if [[ `nkvers | grep '(SP2)' | wc -l` -gt 0 || `nkvers | grep '(SP3)' | wc -l` -gt 0  ]]; then
        rpm -qa|grep libatomic || rpm -ivh soft/mysql/libatomic-7.3.0-20190804.35.p02.ky10.aarch64.rpm
      else
        yum -y install libatomic ${repoCommand}
      fi

    fi
    if [[ ${osType} = "openEuler_x86" ]];then
          yum -y install make ${repoCommand}
    fi
    if [[ ${osType} = "openEuler_arm" || ${osType} = "bcLinux_arm" ]];then
            yum -y install bc ${repoCommand}
            info "openeuler_arm 安装mysql需要依赖包libatomic"
            yum install libatomic -y ${repoCommand}
    fi
    if [[ ${osType}  = "uos_arm" ]];then
          info "统信arm安装mysql需要依赖包libatomic"
          yum install libatomic -y ${repoCommand}
    fi

    retCode=$?
    if [[ ${retCode} != 0 ]]; then
       error "yum安装依赖失败，请手动安装yum源"
       exit 1
    fi
    for softName in gcc-c++ gcc libxslt-devel gd openssl openssl-devel curl  libffi-devel
    do
      info "yum list ${softName} ${repoCommand}"
      result=`yum list ${softName} ${repoCommand}`
      info "${result}"
    done
    if [[ ${osType} = "Kylin_arm" && ${theme} != "zData" ]];then
      info "yum list libatomic ${repoCommand}"
      result=`yum list libatomic ${repoCommand}`
      info "${result}"
    fi
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
   info "yum安装依赖成功"
  endTime=$(date +"%s%N")
  info "检查Yum源配置完成，耗时$( __CalcDuration ${startTime} ${endTime})"

  for libso in libncurses.so.5 libtinfo.so.5 libnsl.so.1 libreadline.so.6
  do
    if [[ `ls /usr/lib64/ | grep ${libso} | wc -l ` -gt 0 ]]; then
      echo "存在${libso}"
    else
      echo "尝试建立${libso}软连接"
      libsoPre=${libso%?}
      libsoPreSo=`ls /usr/lib64/ | grep ${libsoPre}`
      echo "存在的lib包 ${libsoPreSo}"
      if [ -z "${libsoPreSo}" ]; then
        echo "不存在关联的lib包，请手动恢复环境"
        exit 1
      else
        useSo=`ls /usr/lib64/ | grep ${libsoPre} | head -1`
        ln -s /usr/lib64/${useSo} /usr/lib64/${libso}
        echo "使用${useSo}建立软连接完成"
      fi

    fi
  done
}

# 检查操作系统时区
function __CheckTimeZone {
  startTime=$(date +"%s%N")
  type=$1
  if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
    timeZone="CST"
    time=`date`
    result=$(echo $time | grep "${timeZone}" |wc -l)
    if [[ $result -gt 0 ]];then
        info "操作系统时区为CST,检查通过"
    else
        info "操作系统时区不是CST(中国标准时间)，请手动设置为CST"
        exit 1
    fi
  else
    info "此次为标准安装升级，无需执行此步骤 "
  fi
  endTime=$(date +"%s%N")
  info "检查服务器时区完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __ConfigSysParam {
  startTime=$(date +"%s%N")
  if [[ ${installType} != 4 ]];then
    # shellcheck disable=SC2006
    if [[ ${osType} = "Kylin_arm" || ${osType} = "Kylin_x86" || ${osType} = "uos_x86" || ${osType} = "uos_arm" ||
          ${osType} = "openEuler_x86" || ${osType} = "openEuler_arm" || ${osType} = "bcLinux_x86" || ${osType} = "bcLinux_arm" ]];then
      limitFileName="/etc/security/limits.conf"
    elif [[  ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  )&& ${osVersion} == 8.* ]]; then
      limitFileName="/etc/security/limits.conf"
    else
      limitFileName="/etc/security/limits.d/20-nproc.conf"
    fi
    cp ${limitFileName} ${limitFileName}.bak.`date "+%Y%m%d%H%M%S"`
    if [[ $(egrep '(^\*\s+soft\s+nproc\s+)(.*)' ${limitFileName}|wc -l) -gt 0 ]];then
      sed -ri "s/(\*\s+soft\s+nproc\s+)(.*)/\165535/g" ${limitFileName}
    else
      echo "*          soft    nproc     65535">>${limitFileName}
    fi

    if [[ $(egrep '(^\*\s+hard\s+nproc\s+)(.*)' ${limitFileName}|wc -l) -gt 0 ]];then
      sed -ri "s/(\*\s+hard\s+nproc\s+)(.*)/\165535/g" ${limitFileName}
    else
      echo "*          hard    nproc     65535">>${limitFileName}
    fi

    if [[ $(egrep '(^\*\s+soft\s+nofile\s+)(.*)' ${limitFileName}|wc -l) -gt 0 ]];then
      sed -ri "s/(\*\s+soft\s+nofile\s+)(.*)/\165535/g" ${limitFileName}
    else
      echo "*          soft    nofile     65535">>${limitFileName}
    fi

    if [[ $(egrep '(^\*\s+hard\s+nofile\s+)(.*)' ${limitFileName}|wc -l) -gt 0 ]];then
      sed -ri "s/(\*\s+hard\s+nofile\s+)(.*)/\165535/g" ${limitFileName}
    else
      echo "*          hard    nofile     65535">>${limitFileName}
    fi

    if [[ $(egrep '(^root\s+soft\s+nproc\s+)(.*)' ${limitFileName}|wc -l) -gt 0 ]];then
      sed -ri "s/(root\s+soft\s+nproc\s+)(.*)/\1unlimited/g" ${limitFileName}
    else
      echo "root       soft    nproc     unlimited">>${limitFileName}
    fi

    if [[ $(egrep '(^\*\s+soft\s+core\s+)(.*)' ${limitFileName}|wc -l) -gt 0 ]];then
      sed -ri "s/(\*\s+soft\s+core\s+)(.*)/\1unlimited/g" ${limitFileName}
    else
      echo "*          soft    core       unlimited">>${limitFileName}
    fi
    info "检查操作系统调优和设置完成"
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
  ulimit -c unlimited
  endTime=$(date +"%s%N")
  info "检查操作系统调优和设置完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckIp {
#  count=0
#  read -p "请输入安装主机的IP: " readIp
#  while [[ $(${ipPath} addr show |grep " ${readIp}/"|wc -l) == 0 ||  $(echo "${readIp}"|egrep "^(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([1-9]?[0-9]))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([1-9]?[0-9]))$"|wc -l) == 0 ]]; do
#    if [[ $count -gt 2 ]];then
#      warn "IP输入错误次数大于3次，本次安装退出，请确定好IP后重新安装"
#    exit 1
#    fi
#    let count+=1
#    warn "主机IP错误，请重新输入"
#    read -p "请输入安装主机的IP: " readIp
#  done
  realHostIp=($( __ReadValue ${logPath}/evn.cfg realHostIp))
  if [[ ${theme} == "zData" ]];then
    hostIp="127.0.0.1"
  else
    hostIp=${realHostIp}
  fi

  __ReplaceText nodeconfig/installparam.txt "hostIp=" "hostIp=${hostIp}"

  #如果是单机安装，依赖外部为0，更新配置的ip
  installNodeType=$( __readINI zcloud.cfg installtype "install.node.type" )
  if [[ ${installNodeType} ==  "OneNode" ]]; then
    outsideMysql=$( __readINI zcloud.cfg single "dependence.outside.mysql" )
    outsidePrometheus=$( __readINI zcloud.cfg single "dependence.outside.prometheus" )
    outsideMogDB=$( __readINI zcloud.cfg single "dependence.outside.mogdb" )
      if [[ ${outsideMysql} == 0 ]]; then
          sed -i "/^mysql.service.ip/cmysql.service.ip=${hostIp}" zcloud.cfg
      fi
      if [[ ${outsidePrometheus} == 0 ]]; then
          sed -i "/^prometheus.service.ip/cprometheus.service.ip=${hostIp}" zcloud.cfg
      fi
      if [[ ${outsideMogDB} == 0 ]]; then
          sed -i "/^mogdb.service.ip/cmogdb.service.ip=${hostIp}" zcloud.cfg
      fi
  fi

  info "hostIp：${hostIp}"
}

function __CheckHome() {
  startTime=$(date +"%s%N")
  if [[ ! ${workdir} =~ ^${homePath}.*$ ]];then
    error "安装发起目录必须在Home目录下"
    exit 1
  else
    info "安装目录在Home目录下"
  fi
  endTime=$(date +"%s%N")
  info "检查安装目录是否在home目录下完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __AuthSudo {
  if [[ ${installType} = 2 ]];then

    sudoFile=/etc/sudoers
    chmod u+w ${sudoFile}
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+status\s+mysqld)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl status mysqld">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+stop\s+mysqld)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl stop mysqld">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+restart\s+mysqld)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl restart mysqld">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+start\s+mysqld)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl start mysqld">>${sudoFile}
    fi

    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+status\s+zcloud_prometheus)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl status zcloud_prometheus">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+stop\s+zcloud_prometheus)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl stop zcloud_prometheus">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+restart\s+zcloud_prometheus)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl restart zcloud_prometheus">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+start\s+zcloud_prometheus)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl start zcloud_prometheus">>${sudoFile}
    fi

    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+status\s+influxdb)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl status influxdb">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+stop\s+influxdb)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl stop influxdb">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+restart\s+influxdb)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl restart influxdb">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+start\s+influxdb)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl start influxdb">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+status\s+zcloud_keeper_service)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl status zcloud_keeper_service">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+stop\s+zcloud_keeper_service)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl stop zcloud_keeper_service">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+restart\s+zcloud_keeper_service)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl restart zcloud_keeper_service">>${sudoFile}
    fi
    if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/systemctl\s+start\s+zcloud_keeper_service)' ${sudoFile}|wc -l) -eq 0 ]];then
      echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/systemctl start zcloud_keeper_service">>${sudoFile}
    fi
    chmod u-w ${sudoFile}
  fi
}

function __AuthSudoForPodman {
  installPath=$1
  sudoFile=/etc/sudoers
  chmod u+w ${sudoFile}
  if [[ $(egrep "(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:${installPath}/podman/podman)" ${sudoFile}|wc -l) -eq 0 ]];then
    echo "zcloud  ALL=(ALL)        NOPASSWD:${installPath}/podman/podman">>${sudoFile}
  fi
  if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/podman)' ${sudoFile}|wc -l) -eq 0 ]];then
    echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/podman">>${sudoFile}
  fi
  if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/mount)' ${sudoFile}|wc -l) -eq 0 ]];then
    echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/mount">>${sudoFile}
  fi
  if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/umount)' ${sudoFile}|wc -l) -eq 0 ]];then
    echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/umount">>${sudoFile}
  fi
  if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/bin/mkdir)' ${sudoFile}|wc -l) -eq 0 ]];then
    echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/bin/mkdir">>${sudoFile}
  fi
  if [[ $(egrep '(^zcloud\s+ALL=\(ALL\)\s+NOPASSWD:/usr/sbin/dmidecode)' ${sudoFile}|wc -l) -eq 0 ]];then
    echo "zcloud  ALL=(ALL)        NOPASSWD:/usr/sbin/dmidecode">>${sudoFile}
  fi
  chmod u-w ${sudoFile}
}

function __AddLogrotateConf {
  oldVersion=$( __ReadValue ${logPath}/evn.cfg oldVersion)
  logSplit=($( __readINI zcloud.cfg common "log.split" ))
  if [[ ${logSplit} = "0" ]];then
    info "配置跳过此步骤"
  elif [[ ${installType} = 1 || ${installType} = 2 || -f /usr/lib/systemd/system/zcloud_prometheus.service || (${oldVersion} != "" && ${oldVersion} < "3.5.2") ]];then

    template="#path# {
      su zcloud zcloud
      daily
      rotate 10
      missingok
      size 10M
      dateext
      notifempty
      copytruncate
      nocompress
      create 0644 zcloud zcloud
      sharedscripts
      postrotate
          /bin/kill -HUP \`cat /var/run/syslogd.pid 2> /dev/null\` 2> /dev/null || true
      endscript
  }"
    content=`echo "${template}"|sed "s|#path#|${installPath}/prometheus/log/prometheus.log|g"`
    echo "${content}">/etc/logrotate.d/zcloud_prometheus_logrotate.conf

    content=`echo "${template}"|sed "s|#path#|${installPath}/alertmanager/log/alertmanager.log|g"`
    echo "${content}">/etc/logrotate.d/zcloud_alertmanger_logrotate.conf

    content=`echo "${template}"|sed "s|#path#|${installPath}/soft/consul/log/info.log|g"`
    echo "${content}">/etc/logrotate.d/zcloud_consul_logrotate.conf

    content=`echo "${template}"|sed "s|#path#|${installPath}/soft/influx/log/info.log|g"`
    echo "${content}">/etc/logrotate.d/zcloud_influx_logrotate.conf

    content=`echo "${template}"|sed "s|#path#|${installPath}/soft/nginx/nginx/logs/*.log|g"`
    echo "${content}">/etc/logrotate.d/zcloud_nginx_logrotate.conf

    hostName=`cat /etc/hostname`
    dataDir=($( __ReadValue ${logPath}/evn.cfg mysqlDataDir))
    if [[ ${dataDir} = "" ]];then
      path=${installPath}/soft/mysql/data/${hostName}.err
    else
      path=${dataDir}/${hostName}.err
    fi

    content=`echo "${template}"|sed "s|#path#|${path}|g"`
    echo "${content}">/etc/logrotate.d/zcloud_mysql_logrotate.conf

    content=`echo "${template}"|sed "s|#path#|/var/log/zcloud_keepermonitor.log|g"`
    echo "${content}">/etc/logrotate.d/zcloud_keeper_monitor_logrotate.conf
    sed -i "s/zcloud zcloud/root root/g" /etc/logrotate.d/zcloud_keeper_monitor_logrotate.conf
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
}

function __CheckCfgParam {
  installNodeType=$( __readINI zcloud.cfg installtype "install.node.type" )
  echo "installNodeType ${installNodeType}"
  if [[ ${installNodeType} != "OneNode" && ${installNodeType} != "TwoNodes" && ${installNodeType} != "FourNodes" ]]; then
      echo "安装类型配置错误，请修改zcloudBeforeInstall.cfg配置后重新启动安装脚本"
      echo "Example:"
      echo "install.node.type=OneNode"
      echo "install.node.type=TwoNodes"
      echo "install.node.type=FourNodes"
      exit 1
  fi
}

function __CheckDatabaseType {
  databaseType=($( __readINI zcloud.cfg common "database.type" ))
  if [[ ${databaseType} != "MogDB" && ${databaseType} != "MySQL" ]];then
    error "资料库只支持ModDB和MySQL,请修改后再安装"
    exit 1
  fi
  if [[ ${installType} = "4" ]];then
    if [[ -f ${configPath}/consultoken.txt ]];then
      consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
      export CONSUL_HTTP_TOKEN=${consulToken}
      info "consulToken=${CONSUL_HTTP_TOKEN}"
    fi
    if [[ -f ${installPath}/soft/consul/consul/consul ]];then
      driverClassName=`${installPath}/soft/consul/consul/consul kv get zcloudconfig/prod/global/spring.datasource.driverClassName`
      if [[ ${driverClassName} = "org.opengauss.Driver" ]];then
        databaseType="MogDB"
      else
        databaseType="MySQL"
      fi
    else
      opengaussName=`echo org.opengauss.Driver|base64`
      consulIp=$( __readINI zcloud.cfg multiple consul.host )
      if [[ ${consulToken} = "" ]];then
        result=`curl http://${consulIp}:8500/v1/kv/zcloudconfig/prod/global/spring.datasource.driverClassName`
      else
        result=`curl -H "X-Consul-Token: ${consulToken}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/global/spring.datasource.driverClassName`
      fi
      if [[ `echo ${result}|grep "b3JnLm9wZW5nYXVzcy5Ecml2ZXI" |wc -l` -gt 0 ]];then
        databaseType="MogDB"
      else
        databaseType="MySQL"
      fi

    fi

  elif [[ ${installType} = "2" ]]; then
      databaseType="MySQL"
  fi
  info "底层资料库为${databaseType}"
  __ReplaceText ${logPath}/evn.cfg "databaseType=" "databaseType=${databaseType}"
}
