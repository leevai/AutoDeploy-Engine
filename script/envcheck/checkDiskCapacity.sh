installType=#{installType}
diskCapacity=#{diskCapacity}
homePath=#{homePath}
. ../lib/common_unroot.sh

#检查服务器磁盘容量
type=$1
if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
  diskCapacity=$[diskCapacity-1]
  if [[ $(df ${homePath}|awk NR==2'{print}' |awk '{print $2}') -lt $((${diskCapacity}*1024*1024)) && ${type} != "upgrade" ]];then
    error "安装zCloud时服务磁盘空间最少需要准备$[${diskCapacity}+1]G,当前磁盘空间为$(df -h ${homePath}|awk NR==2'{print}' |awk '{print $2}')"
    error "本次安装退出"
    exit 1
  else
    info "主机的磁盘空间满足zcloud正常安装"
  fi

else
  info "此次为标准安装升级，无需执行此步骤"
fi
