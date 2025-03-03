installType=#{installType}
logPath=#{logPath}
packagePath=#{packagePath}
installPath=#{installPath}
configPath=#{configPath}
bakPath=#{bakPath}
homePath=#{homePath}
. ../lib/common_unroot.sh

#检查标准目录
if [[ $( __ReadValue ${logPath}/evn.cfg checkDir) != 1 ]];then
  if [[ $installType = 1 || $installType = 2  ]];then
    if [[ -e ${packagePath} || -e  ${installPath} || -e ${configPath} || -e ${bakPath} ]]; then
      if [[ $installType = 1 ]];then
        installTypeDesc="全新安装"
      else
        installTypeDesc="root升级到非root"
      fi
      error "标准安装文件夹${homePath}/dbaas已存在,此次安装类型为${installTypeDesc},请确定安装类型是否正确，并手动清理${homePath}/dbaas文件夹"
      exit 1
    fi
  else
    info "此次为标准安装升级，无需清理文件夹"
  fi
  __ReplaceText ${logPath}/evn.cfg "checkDir=" "checkDir=1"
else
  info "重试无需执行此步骤"
fi
