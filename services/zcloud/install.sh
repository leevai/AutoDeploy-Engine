#!/bin/bash
serviceAppName=#{serviceAppName}
nodeNum=#{nodeNum}
installNodeType=#{installNodeType}
installType=#{installType}
installPath=#{installPath}
homePath=#{homePath}
workdir=#{workdir}
osType=#{osType}
osVersion=#{osVersion}
oldRelease=#{oldRelease}
release=#{release}
realHostIp=#{hostIp}
theme=#{theme}
databaseType=#{databaseType}
mysqluser=#{mysqluser}
mysqlpassword=#{mysqlpassword}
mysqlhost=#{mysqlhost}
mysqlhostport=#{mysqlhostport}
mogdbuser=#{mogdbuser}
mogdbpassword=#{mogdbpassword}
mogdbport=#{mogdbport}
mogdbhost=#{mogdbhost}
logPath="${homePath}/dbaas/zcloud-log"
logFile="${homePath}/dbaas/zcloud-log/install.log"
packagePath="${homePath}/dbaas/soft-package"
bakPath="${homePath}/dbaas/soft-bak"
configPath="${homePath}/dbaas/zcloud-config"
javaIoTempDir="${logPath}/java-io-tmpdir"
ipPath=($( __ReadValue ${logPath}/evn.cfg ipPath))
ssPath=($( __ReadValue ${logPath}/evn.cfg ssPath))
oldVersion1=($( __ReadValue ${logPath}/evn.cfg oldVersion))
bakTime=($( __ReadValue ${logPath}/evn.cfg bakTimeS))

. ./service/zcloud/zcloud_server_install.sh


function __InstallUnRoot {
  if [[ ${executeUser} = "root" ]];then
    su - zcloud -s /bin/bash $workdir/lib/install_unroot.sh  $workdir
  else
    lib/install_unroot.sh
  fi
}

__ReplaceText ${logPath}/evn.cfg "step=" "step=${item}"
ipPath=`which ip`
ssPath=`which ss`
__ReplaceText ${logPath}/evn.cfg "ipPath=" "ipPath=${ipPath}"
__ReplaceText ${logPath}/evn.cfg "ssPath=" "ssPath=${ssPath}"
__ReplaceText ${logPath}/evn.cfg "theme=" "theme=${theme}"
__ReplaceText ${logPath}/evn.cfg "realHostIp=" "realHostIp=${hostIp}"

__InstallUnRoot

item=($( __ReadValue ${logPath}/evn.cfg step))
realHostIp=($( __ReadValue ${logPath}/evn.cfg realHostIp))


if [[ ${serviceAppName} == "changeZcloudCfg" ]]; then
  #修改zcloud配置文件内容
  __ChangeZcloudCfg
fi
