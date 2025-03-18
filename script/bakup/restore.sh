installPath=$1
bakPath=$2
databaseType=$3



cd ${installPath}
echo "开始还原prometheus数据文件"
echo  "./stop.sh --name prometheus"
./stop.sh --name prometheus
if [[ -d ${installPath}/prometheus/data ]];then
  echo "rm -rf ${installPath}/prometheus/data"
  rm -rf ${installPath}/prometheus/data
fi
echo "cp -r ${bakPath}/data/prometheus/data ${installPath}/prometheus"

cp -r ${bakPath}/data/prometheus/data ${installPath}/prometheus
echo  "./start.sh --name prometheus"
./start.sh --name prometheus

if [[ ${databaseType} == "MySQL"  ]];then
  echo "开始还原MySQL数据文件"
  echo  "./stop.sh --name mysql"
  ./stop.sh --name mysql

  if [[ -d ${installPath}/soft/mysql/data ]];then
    echo "rm -rf {installPath}/soft/mysql/data"
    rm -rf {installPath}/soft/mysql/data
  fi
  echo "cp -f ${bakPath}/data/mysql/data ${installPath}/soft/mysql/"
  cp -f ${bakPath}/date/mysql/data ${installPath}/soft/mysql/

  echo  "./start.sh --name mysql"
  ./start.sh --name mysql
fi

if [[ ${databaseType} == "MogDB"  ]];then
   echo "开始还原MogDB数据文件"
   echo  "./stop.sh --name mogdb"
   ./stop.sh --name mogdb

   if [[ -d ${installPath}/soft/mogdb/data ]];then
     echo "rm -rf {installPath}/soft/mogdb/data"
     rm -rf {installPath}/soft/mogdb/data
   fi
   echo "cp -f ${bakPath}/data/mogdb/data ${installPath}/soft/mogdb/"
   cp -f ${bakPath}/data/mogdb/data ${installPath}/soft/mogdb/

   echo  "./start.sh --name mogdb"
   ./start.sh --name mogdb
fi
