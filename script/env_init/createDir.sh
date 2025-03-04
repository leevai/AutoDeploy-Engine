installType=#{installType}
homePath=#{homePath}
installPath=#{installPath}
packagePath=#{packagePath}
bakPath=#{bakPath}
configPath=#{configPath}
javaIoTempDir=#{javaIoTempDir}


# 文件(夹) 创建和赋权给zcloud
function __CreateDir() {
  filePath=$1
  if [[ ! -e $filePath ]]; then
    mkdir -p "${filePath}";
    info "创建文件夹成功，文件夹路径:${filePath}";
  else
    info "创建文件夹已存在，文件夹路径:${filePath}";
  fi
  chown -R zcloud:zcloud "${filePath}"
}

#paasdata 目录创建和赋权
function __CreatePaasdataDir() {
  startTime=$(date +"%s%N")
  if [[ ${installType} = 1 ]];then
    if [[ -d /paasdata ]];then
      chown -R zcloud:zcloud /paasdata
    elif [[ -L /paasdata ]]; then
      __CreateDir ${homePath}/dbaas/paasdata
      path=`ls -l paasdata |awk '{print $NF}'`
      if [[ -d ${path} ]];then
        chown -R xzcloud:zcloud ${path}
      fi
    else
      __CreateDir ${homePath}/dbaas/paasdata
      # 创建软链接
      ln -s ${homePath}/dbaas/paasdata /
    fi
  elif [[ ${installType} = 2 ]];then
    if [[ -L /paasdata ]];then
      path=`ls -l /paasdata |awk '{print $NF}'`
      if [[ -d ${path} ]];then
        chown -R zcloud:zcloud ${path}
      fi
    elif [[ -d /paasdata ]];then
      chown -R zcloud:zcloud /paasdata
    fi

  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
  endTime=$(date +"%s%N")
  info "paasdata 目录创建和赋权完成，耗时$( __CalcDuration ${startTime} ${endTime})"

}

function __CreateStandardDir() {
  filePath=$1
  if [[ $installType != 4 ]];then
    __CreateDir ${filePath}
  else
    info "此次为标准安装升级，无需创建文件夹"
  fi
}

function __CreateSoftInstallDir() {
  startTime=$(date +"%s%N")
  __CreateStandardDir "${installPath}"
  if [[ ! -d ${installPath}/packages ]];then
    mkdir -p ${installPath}/packages
    mkdir -p ${installPath}/packages/download
    mkdir -p ${installPath}/packages/download/sys
    if [[ -e /etc/nginx/nginx.conf ]];then
      lineNum=`sed -n "/location \/download\//=" /etc/nginx/nginx.conf`
      nginxPackagesPath=`sed -n $[${lineNum}+1]p /etc/nginx/nginx.conf|awk -F' ' '{print $NF}' |awk -F';' '{print $1}'`
      chown -R zcloud:zcloud ${nginxPackagesPath}
      info "chown -R zcloud:zcloud ${nginxPackagesPath}"
    fi
    chmod -R 775 ${installPath}/packages
    ln -s /paasdata ${installPath}/packages/download/paasdata
    chown -R zcloud:zcloud ${installPath}/packages
  fi
  endTime=$(date +"%s%N")
  info "创建软件安装完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}


__CreatePaasdataDir
__CreateStandardDir "${packagePath}"
__CreateSoftInstallDir
__CreateStandardDir "${bakPath}"
__CreateStandardDir "${configPath}"
__CreateDir "${javaIoTempDir}"