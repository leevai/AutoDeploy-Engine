installType=#{installType}
osType=#{osType}
osVersion=#{osVersion}

#操作系统调优和设置
if [[ ${installType} != 4 ]];then
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
  echo "检查操作系统调优和设置完成"
else
  echo "此次为标准安装升级，无需执行此步骤"
fi
ulimit -c unlimited
