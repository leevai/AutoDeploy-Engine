release=#{release}
installPath=#{installPath}
logPath=#{logPath}
workdir=#{workdir}

. ./script/lib/common.sh
. ./script/lib/dir_auth.sh

function __CheckZcloudVersion {
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
    fi
  fi

  if [[ $( __ReadValue ${logPath}/evn.cfg release) = "" ]];then
    __ReplaceText ${logPath}/evn.cfg "release=" "release=${release}"
    __ReplaceText ${logPath}/evn.cfg "oldRelease=" "oldRelease=${oldRelease}"
  fi
}

__CheckZcloudVersion