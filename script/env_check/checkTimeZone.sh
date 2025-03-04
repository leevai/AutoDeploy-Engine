installType=#{installType}
. ./script/lib/common.sh

# 检查操作系统时区
type=$1
if [[ ${installType} != 4 || ${type} == "upgrade" ]];then
  timeZone="CST"
  time=`date`
  result=$(echo $time | grep "${timeZone}" |wc -l)
  if [[ $result -gt 0 ]];then
      echo "操作系统时区为CST,检查通过"
  else
      echo "操作系统时区不是CST(中国标准时间)，请手动设置为CST"
      exit 1
  fi
else
  echo "此次为标准安装升级，无需执行此步骤 "
fi
