installBasePath=#{install_path}
installPath=${installBasePath}/consul

function install_consul() {
    info "开始安装consul "
      __CreateDir "${installPath}/soft/consul/"
      __CreateDir "${installPath}/soft/consul/log"
      #判断是否已解压
      if [[ -d ${installPath}/soft/concul/consul ]]; then
        rm -rf ${installPath}/soft/concul/consul
      fi

      #解压
      tar -xf ./services/consul/soft_pkg/consul.singlenode.tar.gz -C "${installPath}/soft/consul/"

      #添加consul acl
      echo 'acl = {
        enabled = true
        default_policy = "deny"
        enable_token_persistence = true
      }' > ${installPath}/soft/consul/consul/config/agent.hcl

      #进入目录,执行脚本安装consul
      mkdir -p ${installPath}/soft/consul/consul/logs
      nohup ${installPath}/soft/consul/consul/consul agent -server -data-dir=${installPath}/soft/consul/consul/data/ -node=agent-one -config-dir=${installPath}/soft/consul/consul/config/ -bind=127.0.0.1 -bootstrap-expect=1 -client=0.0.0.0 -ui -log-file=${installPath}/soft/consul/consul/logs/ -log-rotate-bytes=10485760 -log-rotate-max-files=10 &>>${installPath}/soft/consul/log/info.log &
      #配置环境变量
#      homedir=`cd ~ && pwd`
#      if [[ ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  ) && ${osVersion} == 8.* ]]; then
#          if [[ $(egrep "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" ${homedir}/.bashrc|wc -l) -eq 0 ]];then
#              echo "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin:/usr/local/Python3.9/bin:/usr/bin" >> ${homedir}/.bashrc
#              echo "export PATH CLASSPATH JAVA_HOME" >> ${homedir}/.bashrc
#          fi
#      else
#      __ReplaceText ${homedir}/.bashrc "PATH=" "PATH=\$PATH:\${JAVA_HOME}/bin:\${JAVA_HOME}/jre/bin:${installPath}/soft/consul/consul/:${installPath}/soft/mysql/mysql/bin"
#      __ReplaceText ${homedir}/.bashrc "export" "export PATH CLASSPATH JAVA_HOME"
#      fi
#      source ${homedir}/.bashrc || true

      sleep 10s
      info "consul install successed"
#      #生成token并设置环境变量-保证consul cli正常使用
#      info "配置consul并生成token文件"
#      #生成文件之前判断是否有consultoken.txt文件
#      if [[ ! -f ${configPath}/consultoken.txt ]]; then
#      ${installPath}/soft/consul/consul/consul acl bootstrap > ${configPath}/consultoken.txt
#      fi
#
#      consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
#      export CONSUL_HTTP_TOKEN=${consulToken}
#
#      CONSUL_TOKEN_PARAM="--spring.cloud.consul.config.acl-token=${consulToken}"
#      info "consul 参数 ${CONSUL_TOKEN_PARAM}"
#      #keeper添加consul acl配置。
#      sed -i "s/--spring.cloud.consul.config.acl-token=.*--/${CONSUL_TOKEN_PARAM} --/" ${configPath}/keeper.yaml
#
#      #检验单节点consul是否部署成功
#      checkConsul=$(${installPath}/soft/consul/consul/consul members | wc -l)
#      if [ "${checkConsul}" == "2" ]; then
#        info "consul install successed"
#      else
#        info "consul install failed"
#        exit 1
#      fi
#      cd ${workdir}
#
#    fi
#    \cp -f script/other/start.sh ${installPath}/soft/consul
#    \cp -f script/other/stop.sh ${installPath}/soft/consul
}

function __CreateDir() {
  filePath=$1
  if [[ ! -e $filePath ]]; then
    mkdir -p "${filePath}";
    info "创建文件夹成功，文件夹路径:${filePath}";
  else
    info "创建文件夹已存在，文件夹路径:${filePath}";
  fi
}

function info() {
    printf "[zcloud dbaas] $@ \n"
}

install_consul