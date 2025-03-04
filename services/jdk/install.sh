osType=#{osType}
osVersion=#{osVersion}
logPath=#{logPath}
installPath=#{installPath}

. ./script/lib/common.sh
. ./script/lib/dir_auth.sh

# 非Root安装JDK
function __CheckJava {
    homedir=`cd ~ && pwd`
    if [[ ((! -e ${homedir}/.bashrc) || ($(cat ${homedir}/.bashrc|grep JAVA_HOME|wc -l) = 0)) || ! -e ${installPath}/soft/java/jdk-17.0.11+9 ]]
    then
      __InstallJava
    fi
    __GetJavaVersion

    if [[ "${java_version_part1}" -ge "17" ]]; then
        if [[ "${java_version_part2}"  -ge "0" ]]; then
            info "JDK Check Sucessed , Version gt 17.0, "
        else
            info "JDK Check Failed   , Version Must gt 17.0, please Uninstall and reinstall 17.0.*"
            exit 1
        fi
    fi
}

function __InstallJava {
    info "This Machine Not Install JDK, Will Install JDK 17 "
    __CreateDir "${installPath}/soft/java/"
    if [[ ${osType}  = "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm"  || ${osType}  = "bcLinux_arm" ]];then
      tar -zxf services/jdk/soft_pkg/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.11_9.tar.gz -C "${installPath}/soft/java/"
    else
      tar -zxf services/jdk/soft_pkg/OpenJDK17U-jdk_x64_linux_hotspot_17.0.11_9.tar.gz -C "${installPath}/soft/java/"
    fi
    retCode=$?
    # retCode=0
    if [[ ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  ) && ${osVersion} == 8.* ]]; then

      echo "JAVA_HOME=${installPath}/soft/java/jdk-17.0.11+9" >> ${homedir}/.bashrc
      if [[ `cat ${homedir}/.bashrc |grep "JAVA_HOME=${installPath}/soft/java/jdk1.8.0_171" |wc -l` > 0 ]];then
        sed -i "s/jdk1.8.0_171/jdk-17.0.11+9/g" ${homedir}/.bashrc
      fi
      echo "CLASSPATH=" "CLASSPATH=\${JAVA_HOME}/lib:\${JAVA_HOME}/jre/lib" >> ${homedir}/.bashrc
      echo "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" >> ${homedir}/.bashrc
      echo "export PATH CLASSPATH JAVA_HOME" >> ${homedir}/.bashrc

    else
    __ReplaceText ${homedir}/.bashrc "JAVA_HOME=" "JAVA_HOME=${installPath}/soft/java/jdk-17.0.11+9"
    __ReplaceText ${homedir}/.bashrc "CLASSPATH=" "CLASSPATH=\${JAVA_HOME}/lib:\${JAVA_HOME}/jre/lib"
    __ReplaceText ${homedir}/.bashrc "PATH=" "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin"
    __ReplaceText ${homedir}/.bashrc "export" "export PATH CLASSPATH JAVA_HOME"
    fi

    JAVA_HOME=${installPath}/soft/java/jdk-17.0.11+9
    if [[ ${osType} = "uos_x86" || ${osType} = "uos_arm" ]]; then
        info "alert uos system profile: ${homedir}/.bashrc"
        sed -ie 's/\[ -f \/etc\/bashrc \] \&\& . \/etc\/bashrc/#\[ -f \/etc\/bashrc \] \&\& . \/etc\/bashrc/g' ${homedir}/.bashrc
        info "alert uos system result: echo $?"
    fi
    source ${homedir}/.bashrc || true
    if [[ ${retCode} == 0 ]]; then
        info "Install JDK 17 Sucessed"
    else
        error "Install JDK 17 Failed"
        exit 1
    fi
}

function __GetJavaVersion {
    if [[ ${osType} = "uos_x86" || ${osType} = "uos_arm" ]]; then
        info "alert uos system profile: ${homedir}/.bashrc"
        sed -ie 's/\[ -f \/etc\/bashrc \] \&\& . \/etc\/bashrc/#\[ -f \/etc\/bashrc \] \&\& . \/etc\/bashrc/g' ${homedir}/.bashrc
        info "alert uos system result: echo $?"
    fi
    source ${homedir}/.bashrc || true
    info "${installPath}/soft/java/jdk-17.0.11+9/bin/java -version 2>${logPath}/javaversion.txt"
    ${installPath}/soft/java/jdk-17.0.11+9/bin/java -version 2>${logPath}/javaversion.txt


    javaVerion=`cat ${logPath}/javaversion.txt |head -n1`

    if [[ "${javaVerion}" =~ (([0-9]+).([0-9]+)) ]]
    then
        java_version=${BASH_REMATCH[1]}
        java_version_part1=${BASH_REMATCH[2]}
        java_version_part2=${BASH_REMATCH[3]}

        info "JDK version: $java_version"
    else
        error "Failed to parse JDK version."
        exit 1
    fi
}

__CheckJava