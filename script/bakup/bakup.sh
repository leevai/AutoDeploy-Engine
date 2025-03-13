installPath=$1
bakPath=$2
databaseType=$3
bakTime="$(date '+%Y%m%d')"
if [[ ! -d ${bakPath}/${bakTime} ]];then
  mkdir ${bakPath}/${bakTime}
fi

if [[ ! -d ${bakPath}/${bakTime}/prometheus ]];then
  mkdir ${bakPath}/${bakTime}/prometheus
fi

cd ${installPath}
echo "开始备份prometheus数据文件"
echo  "./stop.sh --name prometheus"
./stop.sh --name prometheus
echo "cp -r ${installPath}/prometheus/data  ${bakPath}/${bakTime}/prometheus"
cp -r ${installPath}/prometheus/data  ${bakPath}/${bakTime}/prometheus
echo  "./start.sh --name prometheus"
./start.sh --name prometheus

if [[ ${databaseType} == "MySQL"  ]];then
  if [[ ! -d ${bakPath}/${bakTime}/mysql ]];then
    mkdir ${bakPath}/${bakTime}/mysql
    echo "开始备份MySQL数据文件"
    echo  "./stop.sh --name mysql"
    echo "cp -f ${installPath}/soft/mysql/data ${bakPath}/${bakTime}/mysql"
    cp -f ${installPath}/soft/mysql/data ${bakPath}/${bakTime}/mysql
    echo  "./start.sh --name mysql"
    ./start.sh --name mysql
  fi
fi

if [[ ${databaseType} == "MogDB"  ]];then
  if [[ ! -d ${bakPath}/${bakTime}/mogdb ]];then
    mkdir ${bakPath}/${bakTime}/mogdb
    echo "开始备份MogDB数据文件"
    echo  "./stop.sh --name mogdb"
    echo "cp -f ${installPath}/soft/mogdb/data ${bakPath}/${bakTime}/mogdb"
    cp -f ${installPath}/soft/mogdb/data ${bakPath}/${bakTime}/mogdb
    echo  "./start.sh --name mysql"
    ./start.sh --name mysql
  fi
fi
