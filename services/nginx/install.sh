installPath=#{installPath}

function install_nginx() {
    info "开始安装nginx "
      __CreateDir "${installPath}/soft/nginx/"

      #解压
      cp ./services/nginx/soft_pkg/nginx  "${installPath}/soft/nginx/"
      cp ./services/nginx/soft_pkg/nginx.conf  "${installPath}/soft/nginx/"


      nohup ${installPath}/soft/nginx/nginx -c ${installPath}/soft/nginx/nginx.conf > /dev/null 2>&1 &
      sleep 10s
      info "nginx install successed"
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

install_nginx