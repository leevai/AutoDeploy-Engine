installType=#{installType}
osType=#{osType}
theme=#{theme}
repoCommand=#{repoCommand}

#yum安装依赖
if [[ ${installType} != 4 ]];then
  echo "yum安装依赖 ..."
  linux_kernel_version=$(uname -r|awk -F'\\.' '{print $1}')
  if [ $linux_kernel_version -ge 4 ];then
    yum -y --nobest install gcc-c++ gcc libxslt-devel gd gd-devel curl  libffi-devel ${repoCommand}
  else
    yum -y install gcc-c++ gcc libxslt-devel gd gd-devel curl  libffi-devel ${repoCommand}
  fi
  # openssl openssl-devel 可能会版本冲突，判断如果install了就不安装了
  set +e
  opensslStr=`openssl version`
  set -e
  if [[ `echo $opensslStr | grep 'OpenSSL' | wc -l ` -gt 0 ]]; then
    echo "openssl already install"
  else
    echo "start openssl install"
    yum -y  install openssl ${repoCommand}
  fi
  set +e
  opensslDevelStr=`rpm -q openssl-devel`
  set +e
  if [[ `echo $opensslDevelStr | grep 'openssl-devel' | wc -l ` -gt 0 ]]; then
      echo "openssl-devel already install"
  else
      echo "start openssl-devel install"
      yum -y  install openssl-devel ${repoCommand}
  fi
#  #增加perl和perl-libs支持后续nginx编译
#  set +e
#  perlStr=`rpm -q perl`
#  set -e
#  if [[ `echo $perlStr | grep 'perl-' | wc -l ` -gt 0 ]]; then
#      echo "perl already install"
#  else
#      echo "start perl install"
#      yum -y  install perl ${repoCommand}
#  fi
#  set +e
#  perlLibStr=`rpm -q perl-libs`
#  set -e
#  if [[ `echo $perlLibStr | grep 'perl-libs' | wc -l ` -gt 0 ]]; then
#      echo "perl-libs already install"
#  else
#      echo "start perl-libs install"
#      yum -y  install perl-libs ${repoCommand}
#  fi

  if [[ ${osType} = "Kylin_arm" && ${theme} != "zData" ]];then
    if [[ `nkvers | grep '(SP2)' | wc -l` -gt 0 || `nkvers | grep '(SP3)' | wc -l` -gt 0  ]]; then
      rpm -qa|grep libatomic || rpm -ivh soft/mysql/libatomic-7.3.0-20190804.35.p02.ky10.aarch64.rpm
    else
      yum -y install libatomic ${repoCommand}
    fi

  fi
  if [[ ${osType} = "openEuler_x86" ]];then
        yum -y install make ${repoCommand}
  fi
  if [[ ${osType} = "openEuler_arm" || ${osType} = "bcLinux_arm" ]];then
          yum -y install bc ${repoCommand}
          echo "openeuler_arm 安装mysql需要依赖包libatomic"
          yum install libatomic -y ${repoCommand}
  fi
  if [[ ${osType}  = "uos_arm" ]];then
        echo "统信arm安装mysql需要依赖包libatomic"
        yum install libatomic -y ${repoCommand}
  fi

  retCode=$?
  if [[ ${retCode} != 0 ]]; then
     error "yum安装依赖失败，请手动安装yum源"
     exit 1
  fi
  for softName in gcc-c++ gcc libxslt-devel gd openssl openssl-devel curl  libffi-devel
  do
    echo "yum list ${softName} ${repoCommand}"
    result=`yum list ${softName} ${repoCommand}`
    echo "${result}"
  done
  if [[ ${osType} = "Kylin_arm" && ${theme} != "zData" ]];then
    echo "yum list libatomic ${repoCommand}"
    result=`yum list libatomic ${repoCommand}`
    echo "${result}"
  fi
else
  echo "此次为标准安装升级，无需执行此步骤"
fi
 echo "yum安装依赖成功"

for libso in libncurses.so.5 libtinfo.so.5 libnsl.so.1 libreadline.so.6
do
  if [[ `ls /usr/lib64/ | grep ${libso} | wc -l ` -gt 0 ]]; then
    echo "存在${libso}"
  else
    echo "尝试建立${libso}软连接"
    libsoPre=${libso%?}
    libsoPreSo=`ls /usr/lib64/ | grep ${libsoPre}`
    echo "存在的lib包 ${libsoPreSo}"
    if [ -z "${libsoPreSo}" ]; then
      echo "不存在关联的lib包，请手动恢复环境"
      exit 1
    else
      useSo=`ls /usr/lib64/ | grep ${libsoPre} | head -1`
      ln -s /usr/lib64/${useSo} /usr/lib64/${libso}
      echo "使用${useSo}建立软连接完成"
    fi
  fi
done