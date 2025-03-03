installType=#{installType}
defaultCoreNum=#{defaultCoreNum}
. ../lib/common_unroot.sh

#检查服务器CPU核心数；升级时type传了upgrade
type=$1
if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
  coreNum=`cat /proc/cpuinfo | grep 'processor'| wc -l`
  if [[ ${coreNum} -lt ${defaultCoreNum}  && ${type} != "upgrade" ]];then
    error "安装zCloud时服务器CPU核心数最少需要准备${defaultCoreNum},当前CPU核心数为${coreNum}"
    error "本次安装退出"
    exit 1
  fi
else
  info "此次为标准安装升级，无需执行此步骤"
fi
