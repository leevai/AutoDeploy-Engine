installPath=#{installPath}
logPath=#{logPath}
packagePath=#{packagePath}
zDataXNewVersion=#{zDataXNewVersion}

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

__CopyPackageTo