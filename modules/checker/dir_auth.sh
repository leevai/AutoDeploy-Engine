#!/bin/bash
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

function __CreateStandardDir() {
  filePath=$1
  if [[ $installType != 4 ]];then
    __CreateDir ${filePath}
  else
    info "此次为标准安装升级，无需创建文件夹"
  fi
}


function __AuthLicence {
  startTime=$(date +"%s%N")
  if [[ ${installType} != 4 ]];then
    if [[ -f /sys/devices/virtual/dmi/id/product_serial  ]];then
      chmod o+r /sys/devices/virtual/dmi/id/product_serial
    fi

    if [[ -f /sys/devices/virtual/dmi/id/board_serial  ]];then
      chmod o+r /sys/devices/virtual/dmi/id/board_serial
    fi

    if [[ -f /sys/firmware/dmi/tables/smbios_entry_point  ]];then
      chmod o+r /sys/firmware/dmi/tables/smbios_entry_point
    fi

    if [[ -f /dev/mem ]];then
      chmod o+r /dev/mem
    fi

    if [[ -f /sys/firmware/dmi/tables/DMI ]];then
      chmod o+r /sys/firmware/dmi/tables/DMI
    fi
    info "licence赋权成功"
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
  endTime=$(date +"%s%N")
  info "Licence赋权完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckDirExist {
  startTime=$(date +"%s%N")
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
  endTime=$(date +"%s%N")
  info "检查标准目录完成，耗时$( __CalcDuration ${startTime} ${endTime})"

}

function __AuthInstallPackage {
  startTime=$(date +"%s%N")
  chown -R zcloud:zcloud "`pwd`"
  info "安装包修改属主成功"
  endTime=$(date +"%s%N")
  if [[ -d ${installPath} ]];then
    chown -R zcloud:zcloud ${installPath}
  fi
  info "安装包修改属主完成，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckZcloudVersion {
  startTime=$(date +"%s%N")
  if [[ ${release} == "" ]];then
    release="enterprise"
  fi
  if [[ -f ${installPath}/zcloud_release.txt ]];then
    oldRelease=`cat ${installPath}/zcloud_release.txt`
  else
    oldRelease="enterprise";
  fi
  if [[ ${release} != ${oldRelease} ]];then
    if [[ $( __ReadValue ${logPath}/evn.cfg version) = "" && -f ${installPath}/version.txt ]];then
      cd ${workdir}
      oldVersion=`cat ${installPath}/version.txt`
      newVersion=`cat version.txt`
      if [[ ${release}  == "standard" ]];then
        releaseDesc="标准版"
      elif [[ ${release}  == "enterprise" ]];then
        releaseDesc="企业版"
      elif [[ ${release}  == "forMogdb" ]];then
        releaseDesc="for MogDB"
      elif [[ ${release}  == "personal" ]];then
        releaseDesc="个人版"
      elif [[ ${release}  == "community" ]];then
        releaseDesc="社区版"
      fi

      if [[ ${oldRelease}  == "standard" ]];then
        oldReleaseDesc="标准版"
      elif [[ ${oldRelease}  == "enterprise" ]];then
        oldReleaseDesc="企业版"
      elif [[ ${oldRelease}  == "forMogdb" ]];then
        oldReleaseDesc="for MogDB"
      elif [[ ${oldRelease}  == "personal" ]];then
        oldReleaseDesc="个人版"
      elif [[ ${oldRelease}  == "community" ]];then
        oldReleaseDesc="社区版"
      fi


      if [[ ${release}  == "standard" && ${oldRelease} == "enterprise" ]];then
        error "企业版不能升级到标准版"
        exit 1
      elif [[ ${oldRelease} == "forMogdb" || ${oldRelease} == "personal" || ${oldRelease} == "community" ]];then
        error "${oldReleaseDesc}不能升级为${releaseDesc}"
        exit 1
      elif [[ ${oldRelease} == "enterprise" || ${release} != "enterprise"  ]];then
        error "${oldReleaseDesc}不能升级为${releaseDesc}"
        exit 1
      elif [[ ${oldVersion} == "3.7.1" && ${newVersion} == "3.7.1.100" ]];then
        info "当前版本${newVersion} ,原安装版本${oldVersion}"
      elif [[ ${oldVersion}  != ${newVersion} ]];then
        error "标准版升级到企业版使用相同版本的安装包，原安装版本${oldVersion}"
        exit 1
      fi
    fi
  else
    if [[ $( __ReadValue ${logPath}/evn.cfg version) = "" && -f ${installPath}/version.txt ]];then
      cd ${workdir}
      oldVersion=`cat ${installPath}/version.txt`
      newVersion=`cat version.txt`
      oldVersionPart1=`echo ${oldVersion}|awk -F'_' '{print $1}'`
      oldVersionPart2=`echo ${oldVersion}|awk -F'_' '{print $2}'`
      newVersionPart1=`echo ${newVersion}|awk -F'_' '{print $1}'`
      newVersionPart2=`echo ${newVersion}|awk -F'_' '{print $2}'`

      if [[ $( __ReadValue ${logPath}/evn.cfg oldVersion) = "" ]];then
        __ReplaceText ${logPath}/evn.cfg "oldVersion=" "oldVersion=${oldVersion}"
      fi

      if [[ ${oldVersionPart1} > ${newVersionPart1} ]];then
        read -p "升级版本大于等于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion},是否继续升级（yes/no）:" choose
        if [[ ${choose} = "yes" ]];then
          info "继续安装版本${newVersion}------------------------------"
        else
          exit 1
        fi
      elif [[ ${oldVersionPart1} = ${newVersionPart1} ]]; then
        if [[ ${oldVersionPart2} = ${newVersionPart2} ]];then
          read -p "升级版本大于等于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion},是否继续升级（yes/no）:" choose
          if [[ ${choose} = "yes" ]];then
            info "继续安装版本${newVersion}------------------------------"
          else
            exit 1
          fi
        elif [[ ${newVersionPart2} != "" && ${oldVersionPart2} = ""  ]];then
          error "升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
          exit 1
        elif [[ ${oldVersionPart2} != "" && ${newVersionPart2} = ""  ]];then
          info "现在版本${newVersion} ,原安装版本${oldVersion}"
        elif [[ ${oldVersionPart2} > ${newVersionPart2}   ]];then
          read -p "升级版本大于等于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion},是否继续升级（yes/no）:" choose
          if [[ ${choose} = "yes" ]];then
            info "继续安装版本${newVersion}------------------------------"
          else
            exit 1
          fi
        else
          info "现在版本${newVersion} ,原安装版本${oldVersion}"
        fi
      else
        info "现在版本${newVersion} ,原安装版本${oldVersion}"
      fi
      ##判断数据库类型
#      if [[ ${installType} == 4 && (${release} == "forMogdb" || ${release} == "personal" || ${release} == "community") ]];then
#        dbType=`cat ${workdir}/dbType.txt`
#        IFS=','
#        oldDbType=`cat ${installPath}/dbType.txt`
#        for item in ${oldDbType}
#        do
#          if [[ `echo ${dbType} |grep ${item} |wc -l` == 0 ]];then
#            reduce="${reduce}${item} "
#          fi
#        done
#        if [[ ${reduce} != "" ]];then
#          error "原安装zCloud支持${reduce}数据库，但现在安装版本不支持"
#          exit 1
#        fi
#        unset IFS
#      fi

    fi
  fi

  if [[ $( __ReadValue ${logPath}/evn.cfg release) = "" ]];then
    __ReplaceText ${logPath}/evn.cfg "release=" "release=${release}"
    __ReplaceText ${logPath}/evn.cfg "oldRelease=" "oldRelease=${oldRelease}"
  fi
  endTime=$(date +"%s%N")
  info "检查zCloud的版本，耗时$( __CalcDuration ${startTime} ${endTime})"
}

function __CheckZcloudAndZDataVersion {
  startTime=$(date +"%s%N")
  if [[ ${release} == "" ]];then
    release="enterprise"
  fi
  if [[ -f ${installPath}/zcloud_release.txt ]];then
    oldRelease=`cat ${installPath}/zcloud_release.txt`
  else
    oldRelease="enterprise";
  fi
  if [[ $( __ReadValue ${logPath}/evn.cfg version) = "" && -f ${installPath}/version.txt ]];then
      cd ${workdir}
      oldVersion=`cat ${installPath}/version.txt`
      newVersion=`cat version.txt`
      oldVersionPart1=`echo ${oldVersion}|awk -F'_' '{print $1}'`
      oldVersionPart2=`echo ${oldVersion}|awk -F'_' '{print $2}'`
      newVersionPart1=`echo ${newVersion}|awk -F'_' '{print $1}'`
      newVersionPart2=`echo ${newVersion}|awk -F'_' '{print $2}'`

      if [[ $( __ReadValue ${logPath}/evn.cfg oldVersion) = "" ]];then
        __ReplaceText ${logPath}/evn.cfg "oldVersion=" "oldVersion=${oldVersion}"
      fi

      if [[ ${oldVersionPart1} > ${newVersionPart1} ]];then
        error "zCloud升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
        exit 1
      elif [[ ${oldVersionPart1} == ${newVersionPart1} ]]; then
        if [[ ${oldVersionPart2} == ${newVersionPart2} ]];then
          error "zCloud升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
          exit 1
        elif [[ ${newVersionPart2} != "" && ${oldVersionPart2} = ""  ]];then
          error "zCloud升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
          exit 1
        elif [[ ${oldVersionPart2} != "" && ${newVersionPart2} = ""  ]];then
          info "zCloud现在版本${newVersion} ,原安装版本${oldVersion}"
        elif [[ ${oldVersionPart2} > ${newVersionPart2}   ]];then
          error "zCloud升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
          exit 1
        else
          info "zCloud现在版本${newVersion} ,原安装版本${oldVersion}"
        fi
      else
        info "zCloud现在版本${newVersion} ,原安装版本${oldVersion}"
      fi
  fi
#  installDir=`echo ${workdir}|awk -F'/' '{print $NF}'`
#  zDataXNewVersion=`echo ${installDir}|awk -F'_' '{print $4}'`
#  if [[ $( __ReadValue ${logPath}/evn.cfg zdatax_version) = "" && -f ${installPath}/zdatax_version.txt ]];then
#      cd ${workdir}
#      zDataXOldVersion=`cat ${installPath}/zdatax_version.txt`
#
#
#      if [[ $( __ReadValue ${logPath}/evn.cfg zdatax_old_version) = "" ]];then
#        __ReplaceText ${logPath}/evn.cfg "zdatax_old_version=" "zdatax_old_version=${zDataXOldVersion}"
#      fi
#
#      if [[ ${zDataXOldVersion} > ${zDataXNewVersion} ]];then
#        error "zDataX升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
#        exit 1
#      elif [[ ${zDataXOldVersion} == ${zDataXNewVersion} ]]; then
#        error "zDataX升级版本必须大于原安装的版本，现在版本${newVersion} ,原安装版本${oldVersion}"
#        exit 1
#      else
#        info "zDataX现在版本${newVersion} ,原安装版本${oldVersion}"
#      fi
#  fi


  if [[ $( __ReadValue ${logPath}/evn.cfg release) = "" ]];then
    __ReplaceText ${logPath}/evn.cfg "release=" "release=${release}"
    __ReplaceText ${logPath}/evn.cfg "oldRelease=" "oldRelease=${oldRelease}"
  fi
  endTime=$(date +"%s%N")
  info "检查zCloud的版本，耗时$( __CalcDuration ${startTime} ${endTime})"
}


function __CheckNodeNum {
  newNodeNum=$1
  #判断不是多节点参数是否合规
  installNodeType=$( __readINI zcloud.cfg installtype install.node.type )
  if [[ ${installNodeType} == "OneNode" ]]; then
              if [[ ${newNodeNum} != "1" ]]; then
              echo "安装节点配置错误，请重新启动安装脚本"
              echo "Example:"
              echo "    ./install.sh --node 1"
              exit 1
              fi
              newTypeNum=1
  fi
  if [[ ${installNodeType} == "TwoNodes" ]]; then
              if [[ ${newNodeNum} != "1" && ${newNodeNum} != "2" ]]; then
              echo "安装节点配置错误，请重新启动安装脚本"
              echo "Example:"
              echo "    ./install.sh --node 1"
              echo "    ./install.sh --node 2"
              exit 1
              fi
              newTypeNum=2
  fi

  if [[ ${installNodeType} == "FourNodes" ]]; then
              if [[ ${newNodeNum} != "1" && ${newNodeNum} != "2" && ${newNodeNum} != "3" && ${newNodeNum} != "4" ]]; then
              echo "安装节点配置错误，请重新启动安装脚本"
              echo "Example:"
              echo "    ./install.sh --node 1"
              echo "    ./install.sh --node 2"
              echo "    ./install.sh --node 3"
              echo "    ./install.sh --node 4"
              exit 1
              fi
              newTypeNum=4
  fi

  installPath="${homePath}/dbaas/soft-install"

  if [[ -f ${installPath}/installparam.txt ]];then
    #判断和原来的节点数是否一致
    oldNodeNum=$( __ReadValue ${installPath}/installparam.txt nodeNum)
    if [[ ${newNodeNum} != ${oldNodeNum} ]]; then
        echo "当前主机原节点数为${oldNodeNum}，与新输入的节点数${newNodeNum}不一致，请重新安装";
        exit 1
    fi
    #判断升级节点数必须大与等于原来的节点数
    oldTypeNum=$( __ReadValue ${installPath}/installparam.txt installType)
    if [[ ${oldTypeNum} -gt ${newTypeNum} ]]; then
        echo "当前安装类型所需节点数${newTypeNum}必须大于等于原来的安装类型所需节点数${oldTypeNum}，请重新配置安装类型后安装";
        exit 1
    fi

  fi
}

function __CopyPackageTo {
  info "此步骤大概需要执行1m,请等待"
  cp version.txt ${installPath}
  chown zcloud:zcloud ${installPath}/version.txt
  cp nodeconfig/installparam.txt ${installPath}
  chown zcloud:zcloud ${installPath}/installparam.txt

  version=`cat version.txt`
  __ReplaceText ${logPath}/evn.cfg "version=" "version=${version}"
  __ReplaceText ${logPath}/evn.cfg "zdatax_version" "zdatax_version=${zDataXNewVersion}"
  echo ${zDataXNewVersion} >${installPath}/zdatax_version.txt
  chown zcloud:zcloud ${installPath}/zdatax_version.txt
  __CreateDir "${packagePath}/${version}"
  cp -r * ${packagePath}/${version}
  chown -R zcloud:zcloud "${packagePath}/${version}"
}

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