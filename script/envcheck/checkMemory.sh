#!/bin/bash
. ../lib/common_unroot.sh

#检查服务器内存
type=$1
startTime=$(date +"%s%N")
if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
  memorySize=`free -h|grep Mem|awk '{print $2}'|sed -r "s/G$|Gi$//g"`
  defaultMemorySize=($(__readINI nodeconfig/current.cfg service "memory.min.size"))
  if [[ ${memorySize} -lt ${defaultMemorySize} && ${type} != "upgrade" ]];then
    error "安装zCloud时服务器内存最少需要准备${defaultMemorySize}G,当前内存为${memorySize}G"
    error "本次安装退出"
    exit 1
  fi
else
  info "此次为标准安装升级，无需执行此步骤"
fi
endTime=$(date +"%s%N")
info "检查服务器内存完成，耗时$( __CalcDuration ${startTime} ${endTime})"