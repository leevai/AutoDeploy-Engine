#!/bin/bash
. lib/evn_check.sh
. lib/dir_auth.sh
. lib/record_zcloud_server_version.sh
. lib/common_unroot.sh

function Usage {
    wl " "
    wl "Usage: ${SCRIPT_NAME} parameters [optional parameters]"
    wl " "
    wl "                 -h|--help          print help wl"
    wl "                 -c|--capacity      软件安装需要的最小空间"
    wl "                 -r|--release       发行版，支持enterprise/standard"
    wl "                 -i|--hostIp        安装主机的ip"
    wl "                 -t|--theme         主题"
    wl "Example:"
    wl "   ./install.sh --hostIp 192.168.1.1"
    return
}
cp zcloudBeforeInstall.cfg zcloud.cfg
__CheckCfgParam
installNodeType=$( __readINI zcloud.cfg installtype install.node.type )
echo "采用配置 ${installNodeType}"
if [[ ${installNodeType} == "OneNode" ]]; then
    nodeNum="1"
fi


while true;
do
    case "$1" in
        --node)
            nodeNum=$2
            shift 2
            ;;
        -c|--capacity)
            capacity=$2

            if [[ ! "${capacity}" =~ ^[0-9]+G$ ]];then
              info "磁盘空间配置错误，请重新启动安装脚本"
              info "Example:"
              info "    ./install.sh --capacity 500G"
              exit 1
            fi
            shift 2
            ;;
        -i|--hostIp)
            hostIp=$2
            if [[  ${hostIp} == '' || $(ip addr show |grep " ${hostIp}/"|wc -l) == 0 ||  $(echo "${hostIp}"|egrep "^(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([1-9]?[0-9]))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([1-9]?[0-9]))$"|wc -l) == 0 ]];then
              info "主机ip输入错误,请重新输入"
              info "Example:"
              info "    ./check_evn.sh --hostIp 192.168.1.1 --theme zData"
              exit 1
            fi
            shift 2
            ;;
        -t|--theme)
            theme=$2
            shift 2
            ;;
        -h|--help)
            Usage
            exit 0
            ;;
        --)
            shift
            break
            # exit
            ;;
        *)
            break
            ;;
    esac
done
if [[  ${hostIp} == '' || $(ip addr show |grep " ${hostIp}/"|wc -l) == 0 ||  $(echo "${hostIp}"|egrep "^(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([1-9]?[0-9]))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([1-9]?[0-9]))$"|wc -l) == 0 ]];then
  info "主机ip输入错误,请重新输入"
  info "Example:"
  info "    ./check_evn.sh --hostIp 192.168.1.1 --theme zData"
  exit 1
fi
if [[ ${theme} != "zData" ]];then
  info "theme输入错误,请重新输入"
  info "Example:"
  info "    ./check_evn.sh --hostIp 192.168.1.1 --theme zData"
  exit 1
fi

if [[ `ps -ef|grep install.sh|grep -v grep|wc -l` -gt 2 ]];then
  echo "zcloud正在安装中，请勿重复安装"
  exit 1
fi

echo "当前采用节点配置 ${installNodeType} ,当前节点 ${nodeNum}"

#配置参数
if [[ ${installNodeType} == "OneNode" ]]; then
    cp nodeconfig/single.cfg nodeconfig/current.cfg
else
    if [[ ${nodeNum} != 1 ]]; then
        acltoken=$( __readINI zcloud.cfg multiple consul.acl.token )
        if [[ ${acltoken} == "" ]] || [[ ${acltoken} == "acltoken" ]] ; then
            echo "当前节点需要配置consul.acl.token"
            exit 1
        fi
    fi
fi
if [[ ${installNodeType} == "TwoNodes" ]]; then
    cp nodeconfig/double.cfg nodeconfig/current.cfg
fi
if [[ ${installNodeType} == "FourNodes" ]]; then
    cp nodeconfig/four.cfg nodeconfig/current.cfg
fi





stepTotal=45
# 初始化参数
workdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $workdir
item=1
__CheckNodeNum $nodeNum
executeUser=`whoami`
if [[ ${theme} == "zData" ]];then
  homePath="/opt/db_manager_standard"
elif [[ ${executeUser} != "root" ]];then
  homePath=$(cd ~ &&pwd)
else
  homePath=$(su - zcloud -c "cd ~ &&pwd")
fi
logPath="${homePath}/dbaas/zcloud-log"
logFile="${homePath}/dbaas/zcloud-log/install.log"
if [[ ! -e ${logPath} ]];then
  mkdir -p ${logPath}
fi
if [[ ! -f ${logPath}/evn.cfg ]];then
  touch ${logPath}/evn.cfg
fi
function __CheckUser {

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
  installPath="${homePath}/dbaas/soft-install"
  packagePath="${homePath}/dbaas/soft-package"
  bakPath="${homePath}/dbaas/soft-bak"
  configPath="${homePath}/dbaas/zcloud-config"
  javaIoTempDir="${logPath}/java-io-tmpdir"
  startTime=$(date +"%s%N")

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
  endTime=$(date +"%s%N")
  info "检查用户信息完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}



installStartTime=$(date +"%s%N")


#填写安装信息
__ReplaceText nodeconfig/installparam.txt "nodeNum=" "nodeNum=${nodeNum}"
if [[ ${installNodeType} == "OneNode" ]]; then
  __ReplaceText nodeconfig/installparam.txt "installType=" "installType=1"
fi
if [[ ${installNodeType} == "TwoNodes" ]]; then
  __ReplaceText nodeconfig/installparam.txt "installType=" "installType=2"
fi
if [[ ${installNodeType} == "FourNodes" ]]; then
  __ReplaceText nodeconfig/installparam.txt "installType=" "installType=4"
fi

if [[ -f ${workdir}/zcloud_release.txt ]];then
  release=`cat zcloud_release.txt`
else
  release="enterprise"
fi


echo "开始安装zCloud"
h2 "[Step $item/$stepTotal]:  检查zCloud安装类型 ..."; let item+=1
__CheckInstallType



__ReplaceText ${logPath}/evn.cfg "installType=" "installType=${installType}"

h2 "[Step $item/$stepTotal]:  检查安装目录是否在home目录下 ..."; let item+=1
__CheckHome
h2 "[Step $item/$stepTotal]:  安装包修改属主 ..."; let item+=1
__AuthInstallPackage

h2 "[Step $item/$stepTotal]:  检查操作系统版本 ..."; let item+=1
if [[ ${theme} != "zData" ]];then
  __CheckOSVersion
else
  __CheckZDataXOSVersion
fi






h2 "[Step $item/$stepTotal]:  检查服务器时区 ..."; let item+=1
__CheckTimeZone upgrade



h2 "[Step $item/$stepTotal]:  检查服务器磁盘容量 ..."; let item+=1
__GetDiskCapacity upgrade

h2 "[Step $item/$stepTotal]:  检查服务器CPU核心数 ..."; let item+=1
__CheckCpuCore upgrade

h2 "[Step $item/$stepTotal]:  检查服务器内存 ..."; let item+=1
__CheckMemory upgrade


h2 "[Step $item/$stepTotal]:  检查zCloud版本 ..."; let item+=1
if [[ ${theme} != "zData" ]];then
  __CheckZcloudVersion
else
  __CheckZcloudAndZDataVersion
fi

installEndTime=$(date +"%s%N")
info "安装前置检查完成,共耗时$( __CalcDuration ${installStartTime} ${installEndTime})"