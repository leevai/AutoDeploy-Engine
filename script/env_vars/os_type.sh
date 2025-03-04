logPath=#{logPath}

. ./script/lib/common_unroot.sh
. ./script/lib/dir_auth.sh

function __CheckOSVersion {
    str=`cat /etc/system-release`
    if [[ `echo $str | grep 'CentOS' | wc -l ` -gt 0 ]]; then
        osType=CentOS
        osVersion=`echo $str | awk '{print $(NF-1)}' | awk -F'.' '{print $1"."$2}'`
    elif [[ `echo $str | grep 'Red Hat' | wc -l ` -gt 0 ]]; then
        osType=RedHat
        osVersion=`echo $str | awk '{print $(NF-1)}' | awk -F'.' '{print $1"."$2}'`
    elif [[ `echo $str | grep 'Oracle' | wc -l ` -gt 0 ]]; then
        osType=Oracle
        osVersion=`echo $str | awk '{print $(NF)}' | awk -F'.' '{print $1"."$2}'`
    elif [[ `echo $str | grep 'Kylin' | wc -l ` -gt 0 ]]; then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="Kylin_x86"
        else
          osType="Kylin_arm"
        fi
        osVersion=`echo $str | awk '{print $(NF-1)}'`
    elif [[ `echo $str | grep 'uos' | wc -l ` -gt 0 ]];then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="uos_x86"
        else
          osType="uos_arm"
        fi
        osVersion=`echo $str | awk '{print $(NF-1)}'`
    elif [[ `echo $str | grep 'openEuler' | wc -l ` -gt 0 ]];then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="openEuler_x86"
        else
          osType="openEuler_arm"
        fi
        osVersion=`echo $str | grep -oP 'release \K[0-9]+\.[0-9]+' | awk -F'.' '{print $1}'`
    elif [[ `echo $str | grep 'BigCloud Enterprise Linux For Euler release' | wc -l ` -gt 0 || `echo $str | grep 'bclinux For Euler release' | wc -l ` -gt 0 ]];then
        if [[ `uname -i` =~ ^x86.* ]]; then
          osType="bcLinux_x86"
        else
          osType="bcLinux_arm"
        fi
        osVersion=`echo $str | grep -oP 'release \K[0-9]+\.[0-9]+' | awk -F'.' '{print $1"."$2}'`
    else
      error "仅支持CentOS,Red Hat,Kylin,BC Linux for Euler上运行zCloud"
      exit 1
    fi
    if [[ "CentOS" = $osType || "RedHat" = $osType  ]]; then
      if [[ $osVersion < '7.0' ]]; then
          error $osType+"版本应该大于7.0，当前版本为:"$osVersion
          exit 1
      fi
      if [[ $osVersion > '8.9' ]]; then
          error $osType+"版本只支持7.x 8.x，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "Oracle" = $osType ]];then
      if [[ $osVersion < '7.0' ]]; then
          error $osType+"版本应该大于7.0，当前版本为:"$osVersion
          exit 1
      fi
      if [[ $osVersion > '8.9' ]]; then
          error $osType+"版本只支持7.x，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "uos_x86" = $osType || "uos_arm" = $osType ]];then
      if [[ $osVersion -ne "20" ]];then
          error $osType+"版本应该等于20，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "openEuler_x86" = $osType || "openEuler_arm" = $osType ]];then
      if [[ $osVersion -gt 22 || $osVersion -lt  20 ]];then
          error $osType+"版本支持20-22，当前版本为:"$osVersion
          exit 1
      fi
    elif [[ "bcLinux_x86" = $osType || "bcLinux_arm" = $osType ]];then
      if [[ $osVersion != 22.10 && $osVersion != 21.10 ]];then
          error $osType+"版本支持21.10-22.10，当前版本为:"$osVersion
          exit 1
      fi
    else
      if [[ $osVersion -ne "V10" ]]; then
          error $osType+"版本应该等于V10，当前版本为:"$osVersion
          exit 1
      fi
    fi
    __ReplaceText ${logPath}/evn.cfg "osType=" "osType=${osType}"
    __ReplaceText ${logPath}/evn.cfg "osVersion=" "osVersion=${osVersion}"
    echo "${osType};${osVersion}"
}
__CheckOSVersion