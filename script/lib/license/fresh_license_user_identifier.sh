#!/bin/bash

export query_old_soft_id="SELECT  user_id_software FROM dbaas.license_uid LIMIT 1"
export query_license="SELECT content3 AS ct FROM dbaas.license_auth LIMIT 1"
export update_user_id_software="update dbaas.license_uid set user_id_software="
export jar_util_path=lib/license/dbaas-license-decoder.jar
export zcloudCfg=zcloud.cfg

export add_user_id_software_mysql="ALTER TABLE dbaas.license_uid ADD user_id_software varchar(55) DEFAULT NULL COMMENT '随机生成的唯一标识的用户ID标识'"
export add_user_id_software_extra_mysql="ALTER TABLE dbaas.license_uid ADD user_id_software_extra varchar(55) DEFAULT NULL COMMENT '随机生成的唯一标识的用户ID标识备用字段'"

export add_user_id_software_mogdb="ALTER TABLE dbaas.license_uid ADD user_id_software varchar(55) default null"
export add_user_id_software_comment_mogdb="COMMENT ON COLUMN dbaas.license_uid.user_id_software IS '随机生成的唯一标识的用户ID标识'"
export add_user_id_software_extra_mogdb="ALTER TABLE dbaas.license_uid ADD user_id_software_extra varchar(55) default null"
export add_user_id_software_extra_comment_mogdb="COMMENT ON COLUMN dbaas.license_uid.user_id_software_extra IS '随机生成的唯一标识的用户ID标识备用字段'"

homedir=`cd ~ && pwd`
if [[ -f ${homedir}/.bashrc ]];then
  set +e
  source ${homedir}/.bashrc || true
  set -e
fi


# 新增license用户id字段
function addLicenseUserIdColumn() {
     if [[ ${databaseType} == "MySQL" ]];then
      mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      ${mysqlAddr} -uroot  -p${dbaas_password} -h${server_ip} -P${server_port} -N  -e "${add_user_id_software_mysql}"
      ${mysqlAddr} -uroot  -p${dbaas_password} -h${server_ip} -P${server_port} -N  -e "${add_user_id_software_extra_mysql}"
   else
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -t -c "${add_user_id_software_mogdb}"
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -t -c "${add_user_id_software_comment_mogdb}"
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -t -c "${add_user_id_software_extra_mogdb}"
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -t -c "${add_user_id_software_extra_comment_mogdb}"
   fi
}


#刷新license的用户标识
function __Fresh_user_identifier() {

   echo "databaseType:${databaseType}"
   javapath="`echo $JAVA_HOME`/bin/java"
  #查询license
   resultStr=""
   user_id_software=""
   license=""
   update_sql=""
   old_soft_id=""
   set -e
   __QueryDatabaseInfoLicense

   # 添加字段
   set +e
   addLicenseUserIdColumn

   set -e
   if [[ ${databaseType} == "MySQL" ]];then
      license=`mysql -uroot  -p${dbaas_password} -h${server_ip} -P${server_port} -N  -e "${query_license}"`
      old_soft_id=`mysql -uroot  -p${dbaas_password} -h${server_ip} -P${server_port} -N  -e "${query_old_soft_id}"`
   else
      license=`${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -t -c "${query_license}"`
      old_soft_id=`${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -t -c "${query_old_soft_id}"`
   fi

  if [  -z "$license"  ]; then
      info  "未获取到license,无需更新用户标识！"
      return
  fi

   #提取用户标识
   resultStr=`${javapath} -cp ${jar_util_path} com.enmo.license.Decoder ${license}`
   echo  "resultStr:"
   echo  ${resultStr}

  regex="###(.*?)###"
  if [[ $resultStr =~ $regex ]]; then
      mixedId="${BASH_REMATCH[1]}"
      user_id_software=$(parseUid "$mixedId")
      if [ -z "${user_id_software}" ]; then
          info "user_id_software 不能为空,停止更新用户标识"
          return
      fi
      old_soft_id_trim=`echo ${old_soft_id} | xargs`
      user_id_software_trim=`echo ${user_id_software} | xargs`
      if [ "${user_id_software_trim}" = "${old_soft_id_trim}" ]; then
          info "user_id_software用户标识未改变,停止更新用户标识"
          return
      fi
      update_sql="${update_user_id_software}'${user_id_software_trim}'"
      info "${update_sql}"
  fi
  info "user_id_software:${user_id_software_trim},old_soft_id:${old_soft_id_trim}"
   #更新
   if [[ ${databaseType} == "MySQL" ]];then
     mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      ${mysqlAddr} -uroot  -p${dbaas_password} -h${server_ip} -P${server_port} -e "${update_sql}"
   else
     ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "${update_sql}"
   fi

   #重启gateway
   info "准备关闭ap-apiGateway..."
   cd ${installPath}/dbaas-apigateway && ./stop.sh
   info "准备重新拉起ap-apiGateway..."
   cd ${installPath}/dbaas-apigateway && ./start.sh

}


#解析出soft_id
function parseUid() {
   local uid=$1
   local result=""
    # 检查字符串是否包含 "-"
    if [[ $uid == *-* ]]; then
        result="${uid%%-*}"
    else
        result="$uid"
    fi
    echo "$result"
}

#记载配置信息
function __QueryDatabaseInfoLicense() {
  if [[ ${databaseType} = "MogDB" ]];then
      driverName="org.opengauss.Driver"
      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mogdb" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} single mogdb.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} single mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} single mogdb.password)
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mogdb" ))
        server_ip=$(__readINI ${zcloudCfg} multiple mogdb.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mogdb.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mogdb.user)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mogdb.password)
      fi
    else
      driverName="com.mysql.jdbc.Driver"
      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mysql" ))
        if [[ ${dependenceOutside} = "1" ]];then
          server_ip=$(__readINI ${zcloudCfg} single mysql.service.ip)
        else
          server_ip=${hostIp}
        fi
        server_port=$(__readINI ${zcloudCfg} single mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} single mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} single mysql.root.paasword)
      else
        dependenceOutside=($( __readINI zcloud.cfg multiple "dependence.outside.mysql" ))
        server_ip=$(__readINI ${zcloudCfg} multiple mysql.service.ip)
        server_port=$(__readINI ${zcloudCfg} multiple mysql.service.port)
        dbaas_username=$(__readINI ${zcloudCfg} multiple mysql.username)
        dbaas_password=$(__readINI ${zcloudCfg} multiple mysql.root.paasword)

      fi
    fi
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ Utils encode ${dbaas_password}`
}
