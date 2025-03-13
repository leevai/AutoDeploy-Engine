installPath=$1
bakPath=$2
databaseType=$3
bakTime="$(date '+%Y%m%d')"



cd ${installPath}
echo "开始还原prometheus数据文件"
echo  "./stop.sh --name prometheus"
./stop.sh --name prometheus
if [[ -d ${installPath}/prometheus/data ]];then
  echo "rm -rf ${installPath}/data"
  rm -rf ${installPath}/data
fi
echo "cp -r ${bakPath}/${bakTime}/prometheus ${installPath}/prometheus"
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
  cp -f ${bakPath}/mysql/data ${installPath}/soft/mysql/
  echo "cp -f ${bakPath}/mysql/data ${installPath}/soft/mysql/"
  echo  "./start.sh --name mysql"
  ./start.sh --name mysql
  fi
fi

if [[ ${databaseType} == "MogDB"  ]];then
   echo "开始还原MogDB数据文件"
   echo  "./stop.sh --name mogdb"
   ./stop.sh --name mogdb

   if [[ -d ${installPath}/soft/mogdb/data ]];then
     echo "rm -rf {installPath}/soft/mogdb/data"
     rm -rf {installPath}/soft/mogdb/data
   fi
   echo "cp -f ${bakPath}/mogdb/date ${installPath}/soft/mogdb/"
   cp -f ${bakPath}/mogdb/data ${installPath}/soft/mogdb/

   echo  "./start.sh --name mogdb"
   ./start.sh --name mogdb
   fi
fi
