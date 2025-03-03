installType=#{installType}
homePath=#{homePath}
theme=#{theme}
executeUser=#{executeUser}
logPath=#{logPath}
logFile=#{logFile}
. ../lib/common_unroot.sh

#检查并创建用户
if [[ -f ${homePath}/dbaas/zcloud-log/evn.cfg ]];then
  checkUser=($( __ReadValue ${homePath}/dbaas/zcloud-log/evn.cfg checkUser))
fi
if [[ ${installType} == 1 && ${checkUser} == ""  && ${theme} == "zData" ]];then
  if [[ `cat /etc/passwd|grep zcloud:|wc -l` > 0 ]];then
    error "安装失败,zcloud用户已存在,请手动删除后重新创建用户"
    exit 1
  fi
  if [[ ! -d /opt/db_manager_standard  ]];then
    error "安装失败,/opt/db_manager_standard目录不存在,请手动创建目录，并把安装包解压在该目录"
    exit 1
  fi
  if [[ `cat /etc/group|grep zcloud:|wc -l` == 0 ]];then
    groupadd zcloud
  fi
  useradd -g zcloud zcloud -d /home/zcloud
  usermod -d /opt/db_manager_standard zcloud
  mv  /home/zcloud/.b* /opt/db_manager_standard
  if [[ -f /home/zcloud/.kshrc ]];then
     mv  /home/zcloud/.kshrc /opt/db_manager_standard
  fi
  echo 'zcloud:Dbaas#12345' | chpasswd
  chown -R zcloud:zcloud /opt/db_manager_standard
fi

if [[ ${executeUser} = "root" ]];then
  if passwd -S zcloud >/dev/null 2>&1 ; then
    if [[ `passwd -S zcloud|grep LK|wc -l` -gt 0 ]];then
      echo "zcloud用户被锁定"
      exit 1
    fi
    echo "zcloud用户存在"
  else
    echo "zcloud用户不存在"
    exit 1
  fi
fi

chown -R  zcloud:zcloud ${homePath}/dbaas


__ReplaceText ${logPath}/evn.cfg "checkUser=" "checkUser=1"

if [[ ! -f ${logFile} ]];then
  touch ${logFile}
  chown zcloud:zcloud ${logFile}
fi
if [[ ! -f ${logPath}/evn.cfg ]];then
  touch ${logPath}/evn.cfg
  chown zcloud:zcloud ${logPath}/evn.cfg
fi
if [[ ! -f ${logFile} ]];then
  touch ${logFile}
  chown zcloud:zcloud ${logFile}
fi
chown  zcloud:zcloud ${homePath}/dbaas
if [[ ! (`whoami` = "root" || `whoami` = "zcloud") ]];then
  error "执行用户必须是root或者zcloud"
  exit 1;
fi
