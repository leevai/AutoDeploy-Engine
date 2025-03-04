theme=#{theme}

executeUser=`whoami`
if [[ ${theme} == "zData" ]];then
  homePath="/opt/db_manager_standard"
elif [[ ${executeUser} != "root" ]];then
  homePath=$(cd ~ &&pwd)
else
  homePath=$(su - zcloud -c "cd ~ &&pwd")
fi
logPath="${homePath}/dbaas/zcloud-log"
if [[ ! -e ${logPath} ]];then
  mkdir -p ${logPath}
fi
if [[ ! -f ${logPath}/evn.cfg ]];then
  touch ${logPath}/evn.cfg
fi
echo "${homePath}"