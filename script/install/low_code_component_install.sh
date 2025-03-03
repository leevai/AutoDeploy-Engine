#!/bin/bash

function __InstallPython3_9 {
  info "安装python3.9.."
  pythonInstallVersion=3.9
  pythonCommand="python3.9"
  if [[ ${osType}  = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm" ]];then
      pythonCommand="python3.9_enmo"
  fi
  pipCommand="pip3.9"
  if [[ ${osType}  = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm" ]];then
      pipCommand="pip3.9_enmo"
  fi
  set +e
    versionV=`${pythonCommand} -V`>>${logFile}
    code=$?
  set -e
  if [[ ${code} != "0" ]];then
    yum install -y libffi-devel ${repoCommand}
    tar -xvf soft/python/Python-${pythonInstallVersion}.15.tar.xz -C"soft/python"
    mkdir -p /usr/local/Python3.9
    chmod 755 /usr/local/Python3.9
    cd soft/python/Python-${pythonInstallVersion}.15
    ./configure --prefix=/usr/local/Python3.9
    make
    make install
    ln -sf /usr/local/Python3.9/bin/python3.9 /usr/bin/${pythonCommand}
    ln -sf /usr/local/Python3.9/bin/pip3.9 /usr/bin/${pipCommand}
    if [[ ! -f  /usr/bin/python3.9 ]];then
      ln -sf /usr/local/Python3.9/bin/python3.9 /usr/bin/python3.9
    fi
    cd ${workdir}
  else
    set +e
    ${pythonCommand} -c "import _ctypes"
    code=$?
    set -e
    if [[ ${code} != "0" ]];then
      yum install -y libffi-devel ${repoCommand}
      rm -rf /usr/local/Python3.9

      tar -xvf soft/python/Python-${pythonInstallVersion}.15.tar.xz -C"soft/python"
      mkdir -p /usr/local/Python3.9
      chmod 755 /usr/local/Python3.9
      cd soft/python/Python-${pythonInstallVersion}.15
      ./configure --prefix=/usr/local/Python3.9
      make
      make install
      ln -sf /usr/local/Python3.9/bin/python3.9 /usr/bin/${pythonCommand}
      ln -sf /usr/local/Python3.9/bin/pip3.9 /usr/bin/${pipCommand}
      if [[ ! -f  /usr/bin/python3.9 ]];then
        ln -sf /usr/local/Python3.9/bin/python3.9 /usr/bin/python3.9
      fi
      cd ${workdir}
    fi
    if [[ `echo ${versionV}|awk '{print $NF}'` =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
    then
        pythonVersion=${BASH_REMATCH[1]}
        pythonVersion_part1=${BASH_REMATCH[2]}
        pythonVersion_part2=${BASH_REMATCH[3]}
        info "python version: ${pythonVersion}"
        version=${pythonVersion_part1}.${pythonVersion_part2}
        set +e
        pythonPath=`which python3.9`
        set -e
        info "python path: ${pythonPath}"
        if [[ ${version} = ${pythonInstallVersion} && ${pythonPath} = "/usr/bin/${pythonCommand}" ]];then
          info "已安装python3.9，无需重复安装"
        else
          tar -xvf soft/python/Python-${pythonInstallVersion}.15.tar.xz -C"soft/python"
          mkdir -p /usr/local/Python3.9
          chmod 755 /usr/local/Python3.9
          cd soft/python/Python-${pythonInstallVersion}.15
          ./configure --prefix=/usr/local/Python3.9
          make
          make install
          ln -sf /usr/local/Python3.9/bin/python3 /usr/bin/${pythonCommand}
          ln -sf /usr/local/Python3.9/bin/pip3 /usr/bin/${pipCommand}
          if [[ ! -f  /usr/bin/python3.9 ]];then
            ln -sf /usr/local/Python3.9/bin/python3.9 /usr/bin/python3.9
          fi
          cd ${workdir}
        fi
    else
        info "Failed to parse python version."
        exit 1
    fi
  fi
}

function __InstallPython3_9_patch {
  currentTime=`date "+%Y-%m-%d_%H%M"`
  currentDir=${workdir}/jar/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/patch

  info "开始python3.9 补丁包升级"
  if [[ ! -d /usr/local/Python3.9/lib/python3.9 ]];then
      info "python3.9 install directory:/usr/local/Python3.9/lib/python3.9 is not exist"
      exit 1
  fi
  # upgrade email
  if [[ -d /usr/local/Python3.9/lib/python3.9/email ]];then
      mv /usr/local/Python3.9/lib/python3.9/email /usr/local/Python3.9/lib/python3.9/email.bak.${currentTime}
  fi
  cp -rp ${currentDir}/email /usr/local/Python3.9/lib/python3.9/
  # upgrade urllib
  if [[ -d /usr/local/Python3.9/lib/python3.9/urllib ]];then
      mv /usr/local/Python3.9/lib/python3.9/urllib /usr/local/Python3.9/lib/python3.9/urllib.bak.${currentTime}
  fi
  cp -rp ${currentDir}/urllib /usr/local/Python3.9/lib/python3.9/
  # delete mailcap
  if [[ -f /usr/local/Python3.9/lib/python3.9/mailcap.py ]];then
      mv /usr/local/Python3.9/lib/python3.9/mailcap.py /usr/local/Python3.9/lib/python3.9/mailcap.py.bak.${currentTime}
  fi
  #重启服务
  if [[ `ps -ef|grep "DBaas-Lowcode-WorkFlow"|grep -v grep |wc -l` -gt 0  ]];then
      info "开始重启服务DBaas-Lowcode-WorkFlow"
      ps -ef |grep "DBaas-Lowcode-WorkFlow"|grep -v grep | awk '{print $2}' | xargs kill -9
      sleep 2
      info "重启服务DBaas-Lowcode-WorkFlow完成"
  fi

  if [[ `ps -ef|grep "ansible_executor"|grep -v grep |wc -l` -gt 0  ]];then
      info "开始重启服务ansible_executor"
      ps -ef |grep "ansible_executor"|grep -v grep | awk '{print $2}' | xargs kill -9
      sleep 2
      info "重启服务ansible_executor完成"
  fi
  sleep 2

  info "python3.9 补丁更新完成"
}

function __InstallAnsible {
  info "安装Ansible环境..."
  if [[ ${installType} != 4 ]];then
    cd soft/ansible
    tar -xvf ansible-install.tar.gz
    cd ansible-install
    if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
      rm -f psycopg2_binary-2.9.5-cp39-cp39-manylinux_2_24_aarch64.whl
    fi
    if [[ ${osType} = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm" ]];then
      pip3.9_enmo install *whl
    else
      pip3.9 install *whl
    fi
    info "Ansible环境安装完成"
    info "安装gunicorn环境..."
    cd ..
    tar -xvf gunicorn20.1.0.tar.gz
    cd gunicorn
    if [[ ${osType} = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm"  ]];then
      pip3.9_enmo install *whl
    else
      pip3.9 install *whl
    fi
    info "gunicorn环境安装完成"
    chmod -R 755 /usr/local/Python3.9/lib/python3.9/site-packages/
    if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
      rm -rf /usr/local/Python3.9/lib/python3.9/site-packages/_cffi_backend.cpython-39-aarch64-linux-gnu.so
      rm -rf /usr/local/Python3.9/lib/python3.9/site-packages/cffi-1.15.1.dist-info
      rm -rf /usr/local/Python3.9/lib/python3.9/site-packages/cffi.libs
      rm -rf /usr/local/Python3.9/lib/python3.9/site-packages/cffi
    fi
    filePath=${homePath}/.bashrc
    if [[ $(egrep "PATH=\\\$PATH:/usr/local/Python3.9/bin" ${filePath}|wc -l) -eq 0 ]];then
      echo "PATH=\$PATH:/usr/local/Python3.9/bin:/usr/bin">>${filePath}
      echo "export PATH">>${filePath}
    fi
    set +e
    source ${filePath} || true
    set -e
    if [[ ${osType}  = "uos_arm" ]];then
      source ${filePath} || true
    else
      source ${filePath} || true
    fi
    filePath=${homePath}/.bash_profile
    if [[ $(egrep "PATH=\\\$PATH:/usr/local/Python3.9/bin" ${filePath}|wc -l) -eq 0 ]];then
      echo "PATH=\$PATH:/usr/local/Python3.9/bin:/usr/bin">>${filePath}
      echo "export PATH">>${filePath}
    fi
    set +e
    source ${filePath} || true
    set -e
    if [[ ${osType}  = "uos_arm" ]];then
      source ${filePath} || true
    else
      source ${filePath} || true
    fi
    export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
    filePath=/etc/profile
    if [[ $(egrep "PATH=\\\$PATH:/usr/local/Python3.9/bin" ${filePath}|wc -l) -eq 0 ]];then
      echo "PATH=\$PATH:/usr/local/Python3.9/bin:/usr/bin">>${filePath}
      echo "export PATH">>${filePath}
    fi
    set +e
    source ${filePath} || true
    set -e
    if [[ ${osType}  = "uos_arm" ]];then
      source ${filePath} || true
    else
      source ${filePath} || true
    fi
    cd ${workdir}
  fi
}
function __InstallAnsibleAgent() {
  cd ${workdir}
  mkdir -p /usr/share/ansible/plugins/connection
  mkdir -p /usr/share/ansible/plugins/modules
  cp soft/ansible/zcloudAgent.py /usr/share/ansible/plugins/connection
  cp soft/ansible/execute_self_script.py /usr/share/ansible/plugins/modules
  chown -R zcloud:zcloud /usr/share/ansible/plugins
  chmod -R 755 /usr/share/ansible/
  mkdir -p /etc/ansible
  echo "[defaults]
connection_plugins = /usr/share/ansible/plugins/connection
transport = zcloudAgent
remote_tmp = /tmp
local_tmp = /paasdata
system_tmpdirs = /tmp
nocolor = 1" >/etc/ansible/ansible.cfg
  chmod -R 755 /etc/ansible
  chmod -R 755 /etc/ansible/ansible.cfg
}

function __CloseSeLinux {
  seLinuxConfigPath="/etc/selinux/config"
  if [[ $(egrep '(^SELINUX=)(.*)' ${seLinuxConfigPath}|wc -l) -gt 0 ]];then
    sed -ri "s/(^SELINUX=)(.*)/\1disabled/g" ${seLinuxConfigPath}
  else
    echo "SELINUX=disabled">>${seLinuxConfigPath}
  fi
  set +e
  setenforce 0
  set -e
}

function __PrepareVarTmpDirForPodman() {
  if [[ ! -d /var/tmp ]];then
    sudo mkdir -p /var/tmp
  fi
  freespace=$(df -P '/var/tmp'|tail -n 1|awk '{print $4}')
  # 如果/var/tmp小于300M就临时mount一个空间
  if [[ ${freespace} -lt 307200 ]];then
    dd if=/dev/zero of=${installPath}/podman/podmantmpdir bs=1M count=300
    export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin;mkfs.xfs ${installPath}/podman/podmantmpdir
    sudo mount -t xfs ${installPath}/podman/podmantmpdir /var/tmp/
  fi
}


function __CleanVarTmpDirForPodman() {
  if [ -f ${installPath}/podman/podmantmpdir ] && df |grep '/var/tmp'|grep loop;then
    sudo umount /var/tmp
    rm -f ${installPath}/podman/podmantmpdir
  fi
}

function __InstallPodmanOnKylin() {
  if rpm -q podman;then
    info "podman.rpm已经安装，跳过此步"
  else
    yum install -y podman ${repoCommand}
  fi
  if rpm -q podman;then
    if [[ ! -d ${installPath}/podman ]];then
      mkdir ${installPath}/podman
    fi
    cp -r ${workdir}/soft/podman/images ${installPath}/podman
    if [[ -f /usr/bin/podman ]];then
      cp /usr/bin/podman ${installPath}/podman
    fi
    if [[ ! -f /etc/containers/storage.conf ]];then
      cp ${workdir}/soft/podman/${osType}/containers/storage.conf /etc/containers/
    fi
    if [[ ! -f /etc/containers/registries.conf ]];then
      cp ${workdir}/soft/podman/${osType}/containers/registries.conf /etc/containers/
    fi
    if [[ -f /usr/local/bin/runc ]];then
      cp /usr/local/bin/runc ${installPath}/podman
    elif [[ -f /usr/bin/runc ]];then
      cp /usr/bin/runc ${installPath}/podman
    fi
    if [[ ! -d ${installPath}/podman/run ]];then
      mkdir ${installPath}/podman/run
    fi
    if [[ ! -d ${installPath}/podman/lib ]];then
      mkdir ${installPath}/podman/lib
    fi
    if [[ -f /etc/containers/storage.conf ]];then
      sed -i "s|runroot\s*=\s*\"/.*\"|runroot = \"${installPath}/podman/run\"|g" /etc/containers/storage.conf
      sed -i "s|graphroot\s*=\s*\"/.*\"|graphroot = \"${installPath}/podman/lib\"|g" /etc/containers/storage.conf
    fi
    chown -R zcloud:zcloud ${installPath}/podman
    info "安装podman成功"
  else
    error "安装podman失败"
    exit 1
  fi
}

function __InstallPodman() {
  info "开始安装 Podman"
  __CloseSeLinux
  if [[ ! -f /etc/resolv.conf ]];then
    touch /etc/resolv.conf
  fi
  if [[ -f /etc/containers/storage.conf ]];then
      sed -i "s|runroot\s*=\s*\"/.*\"|runroot = \"${installPath}/podman/run\"|g" /etc/containers/storage.conf
      sed -i "s|graphroot\s*=\s*\"/.*\"|graphroot = \"${installPath}/podman/lib\"|g" /etc/containers/storage.conf
  fi
  # 如果已经存在镜像则更新，应对升级的情况
  if [[ -d ${installPath}/podman/images ]];then
    cp -r ${workdir}/soft/podman/images ${installPath}/podman
    chown -R zcloud:zcloud ${installPath}/podman
  fi
  # os is Kylin_arm or Kylin_x86
  if [[ ${osType} = "Kylin_arm" || ${osType} = "Kylin_x86" ]]; then
    __InstallPodmanOnKylin
    return 0
  fi
  if rpm -q libseccomp && rpm -q conmon && [ -f "${installPath}/podman/podman" ] && [ -f "${installPath}/podman/runc" ] && [[ -f /etc/containers/policy.json ]];then
    info "podman已经安装，安装完成"
    return 0
  fi
  # os is redhat centos uos
  # copy podman to dir
  if [[ ! -d ${installPath}/podman ]];then
    mkdir ${installPath}/podman
  fi
  cp -r ${workdir}/soft/podman/images ${installPath}/podman
  cp -r ${workdir}/soft/podman/${osType}/* ${installPath}/podman
  chmod -R 755 ${installPath}/podman
  cd ${installPath}/podman
  # check containers config
  if [[ ! -d /etc/containers ]];then
    mkdir /etc/containers
  fi
  cp -r containers/* /etc/containers

  if [[ ! -d ${installPath}/podman/run ]];then
    mkdir ${installPath}/podman/run
  fi
  if [[ ! -d ${installPath}/podman/lib ]];then
    mkdir ${installPath}/podman/lib
  fi
  if [[ -f /etc/containers/storage.conf ]];then
    sed -i "s|runroot\s*=\s*\"/.*\"|runroot = \"${installPath}/podman/run\"|g" /etc/containers/storage.conf
    sed -i "s|graphroot\s*=\s*\"/.*\"|graphroot = \"${installPath}/podman/lib\"|g" /etc/containers/storage.conf
  fi
  # check cni config
  if [[ ! -f /etc/cni/net.d/87-podman-bridge.conflist ]];then
    if [[ ! -d /etc/cni/net.d ]];then
      mkdir -p /etc/cni/net.d
    fi
    cp 87-podman-bridge.conflist /etc/cni/net.d
  fi
  # check cni bin
  if [[ ! -f /opt/cni/bin/loopback ]];then
    tar zxf cni.tar.gz -C /opt
  fi
  # check libseccomp
  if rpm -q libseccomp;then
      info "libseccomp已经安装，跳过此步"
    else
      rpm -ivh rpms/libseccomp-*.rpm
  fi
  # check conmon binary file
  if rpm -q conmon;then
      info "conmon已经安装，跳过此步"
    else
      rpm -ivh rpms/conmon-*.rpm
  fi
  if [[ ${osType} = "openEuler_arm" || ${osType} = "openEuler_x86" || ${osType} = "bcLinux_arm" || ${osType} = "bcLinux_x86" ]]; then
    if rpm -q ostree;then
      info "ostree已经安装，跳过此步"
    else
      yum install ostree -y ${repoCommand}
    fi
  fi
  __useFuseOverlayFsTool
  chown -R zcloud:zcloud ${installPath}/podman
  cd ${workdir}
  info "podman 安装完成"
}

function __useFuseOverlayFsTool() {
  if [[ ${osType} != "RedHat" && ${osType} != "CentOS" ]]; then
    return 0
  fi
  if df -T / |tail -n 1| grep ' xfs ' > /dev/null 2>&1 && xfs_info / |grep ftype=0 > /dev/null 2>&1;then
    if rpm -q fuse3-libs;then
        info "fuse3-libs已经安装，跳过此步"
      else
        rpm -ivh ${installPath}/podman/rpms/fuse3-libs-3.6.1-4.el7.x86_64.rpm
    fi
    if rpm -q fuse-overlayfs;then
        info "fuse-overlayfs已经安装，跳过此步"
      else
        rpm -ivh ${installPath}/podman/rpms/fuse-overlayfs-0.7.2-6.el7_8.x86_64.rpm
    fi
    sed -i "s|#mount_program|mount_program|g" /etc/containers/storage.conf
  fi
}

function __KillNginxOccupyMountPoint() {
  mnt_point="$1"
  # 使用awk来直接提取PID，同时避免了/mountinfo的问题
  nginx_pids=$(grep -l "$mnt_point" /proc/[0-9]*/mountinfo | awk -F/ '{print $3}' | xargs -I{} grep -lE 'nginx' /proc/{}/cmdline | awk -F/ '{print $3}')

  if [ -z "$nginx_pids" ]; then
      return 0
  fi

  # 将所有nginx进程PID合并为一个字符串，用空格分隔
  nginx_pids_str=$(echo $nginx_pids | tr ' ' '\n' | sort -u | tr '\n' ' ')

  if [ -n "$nginx_pids_str" ]; then
      info "发现以下nginx进程占用挂载点 $mnt_point，准备集体终止..."
      info "PID列表: $nginx_pids_str"
      # 使用kill命令终止所有列出的nginx进程
      kill -15 $nginx_pids_str
      info "nginx进程已尝试终止。"
  fi
}


function __ShowOtherProcessOccupyMountPoint() {
  mnt_point="$1"
  # 使用awk来直接提取PID，同时避免了/mountinfo的问题
  other_pids=$(grep -l "$mnt_point" /proc/[0-9]*/mountinfo | awk -F/ '{print $3}')

  if [ -z "$other_pids" ]; then
      return 0
  fi

  # 将所有other进程PID合并为一个字符串，用空格分隔
  other_pids_str=$(echo $other_pids | tr ' ' '\n' | sort -u | tr '\n' ' ')

  if [ -n "$other_pids_str" ]; then
      info "发现以下进程占用podman挂载点 $mnt_point"
      info "PID列表: $other_pids_str"
      info "请手动处理或强制终止这些进程后再尝试。"
      exit 1
  fi
}

function __InstallMagicScriptExecutor() {
  info "开始安装 magic-script-executor"
  if [[ -d ${installPath}/magic-script-executor ]];then
    __AddToKeeper magic-script-executor
    mountPointID=$(mount |grep podman|grep overlay|grep '/merged'|awk '{print $3}'|awk -F'/' '{print $9}')
    cd ${installPath}/magic-script-executor
    ./stop.sh
    cd ${workdir}
    sleep 2
    mergedPoint=$(mount |grep podman|grep overlay|grep '/merged'|awk '{print $3}')
    if [ -n "$mergedPoint" ];then
      sudo /usr/bin/umount $mergedPoint
    fi
    shmPoint=$(mount |grep podman|grep overlay|grep '/shm'|awk '{print $3}')
    if [ -n "$shmPoint" ];then
      sudo /usr/bin/umount $shmPoint
    fi
    sleep 2
    if [ -n "$mountPointID" ];then
      __KillNginxOccupyMountPoint "$mountPointID"
      sleep 1
      __ShowOtherProcessOccupyMountPoint "$mountPointID"
    fi
    sleep 2
  fi
  if sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc ps|grep magic-script-executor;then
    sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc rm -f magic-script-executor
  fi
  sleep 2
  if sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc ps -a|grep magic-script-executor;then
    sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc rm -f magic-script-executor
  fi
  sleep 2
  if sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc images|grep magic_script_executor_app;then
    sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc rmi magic_script_executor_app:v1.0.0
  fi
  __PrepareVarTmpDirForPodman
  sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc load -i ${installPath}/podman/images/magic_script_executor_app-v1.0.0.tar
  __CleanVarTmpDirForPodman
  consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
  if [[ ${installNodeType} == "OneNode" ]]; then
    consulIp=${hostIp}
  else
    consulIp=$( __readINI ${workdir}zcloud.cfg multiple consul.host )
  fi
  if [[ ${osType} = "RedHat" && ${osVersion} == 8.* ]]; then
    sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc run -d --network host -v /paasdata/:/paasdata/  --security-opt seccomp=unconfined  --name magic-script-executor magic_script_executor_app:v1.0.0 --consul.endpoint=http://${consulIp}:8500 --consul.token=${consulToken} --global.api_addr=:18291
  else
    sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc run -d --network host -v /paasdata/:/paasdata/ --name magic-script-executor magic_script_executor_app:v1.0.0 --consul.endpoint=http://${consulIp}:8500 --consul.token=${consulToken} --global.api_addr=:18291
  fi
  sleep 2
  if [[ -d ${installPath}/magic-script-executor ]];then
    cd ${installPath}/magic-script-executor
    ./start.sh
    cd ${workdir}
    sleep 2
  fi
  if sudo ${installPath}/podman/podman --runtime ${installPath}/podman/runc ps|grep magic-script-executor;then
    info "启动magic-script-executor容器成功"
  else
    error "启动magic-script-executor容器失败"
    exit 1
  fi
  if [[ ${installType} = 4 ]];then
    __AddToKeeper "magic-script-executor"
  fi
  cd ${workdir}
  if [[ ! -d ${installPath}/magic-script-executor ]];then
    mkdir ${installPath}/magic-script-executor
  fi
  cp script/other/start.sh ${installPath}/magic-script-executor
  cp script/other/stop.sh ${installPath}/magic-script-executor
  info "magic-script-executor 安装完成"
}


function __InstallLowCodeEnv() {
  nodeNum=$( __ReadValue nodeconfig/installparam.txt nodeNum)
  if [[  $( __readINI nodeconfig/current.cfg service low-code ) == ${nodeNum} ]]; then
    lowCodeServiceNum=`ps -ef|egrep "ansible_executor.py|DBaas-Lowcode-WorkFlow/manage.py"|grep -v grep |wc -l`
    if [[ (${installType} = 1 || ${lowCodeServiceNum} = 0)]];then
      if [[ ${executeUser} != "root"  ]];then
        error "首次安装低代码平台需要root执行"
        exit 1
      fi
#      if [[ ${databaseType} == "MySQL" ]];then
#        tar -zxvf soft/lowcode_for_mysql.tar.gz -C "/paasdata"
#      else
#        tar -zxvf soft/lowcode_for_mogdb.tar.gz -C "/paasdata"
#      fi



      #chown -R zcloud:zcloud /paasdata/platform

      __InstallPython3_9
      if [[ ${installType} != 4  ]];then
        __InstallAnsible

        __InstallAnsibleAgent
      fi
    else
      if [[ -d /usr/share/ansible/plugins ]];then
        chown -R zcloud:zcloud /usr/share/ansible/plugins
        if [[ -d /paasdata/lowcode ]];then
          \cp -rf /paasdata/lowcode/* /paasdata
          mv /paasdata/lowcode /paasdata/lowcode.bak
        fi
#        if [[ ${databaseType} == "MySQL" ]];then
#          tar -zxvf soft/lowcode_for_mysql.tar.gz -C "/paasdata"
#        else
#          tar -zxvf soft/lowcode_for_mogdb.tar.gz -C "/paasdata"
#        fi
#        chown -R zcloud:zcloud /paasdata/platform
      fi

      info "无需安装低代码运行环境"
    fi
    __InstallPython3_9_patch
    __InstallPodman
    if [[ ! -e /paasdata/lowcodedata ]];then
      mkdir -p  /paasdata/lowcodedata
    fi
    \cp -f soft/lowcodePresetAbility.tar.gz /paasdata/lowcodedata
    if [[ ! -e /paasdata/lowcodedata/script-executor ]];then
      mkdir -p  /paasdata/lowcodedata/script-executor
    fi
    chmod 755 /paasdata/lowcodedata/script-executor
    chown -R zcloud:zcloud  /paasdata/lowcodedata

      __preparePythonSource

      __preparePythonPip2pi

      __prepareAnsibleModule


  else
    info "当前节点无需安装低代码"
  fi
}
function __QueryDatabaseInfo() {
  if [[ ${databaseType} == "MogDB" ]];then

      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI ${zcloudCfg} single "dependence.outside.mogdb" ))
        if [[ ${dependenceOutside} == "1" ]];then
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
      if [[ ${installNodeType} == "OneNode" ]]; then
        dependenceOutside=($( __readINI zcloud.cfg single "dependence.outside.mysql" ))
        if [[ ${dependenceOutside} == "1" ]];then
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
    dbaas_paasword_encode=`cd ${workdir}/lib;${installPath}/soft/java/jdk-17.0.11+9/bin/java -classpath ./ SecurityUtils encode ${dbaas_password}`
}

function __CreateLowCodeSchema() {
    __QueryDatabaseInfo
    if [[ ${databaseType} == "MySQL" ]];then
      mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port}  -e "CREATE DATABASE IF NOT EXISTS lowcodeworkflow;"
    else
      set +e

      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "CREATE SCHEMA lowcodeworkflow authorization dbaas"
      set -e
    fi
}

function __InstallLowCodeSoft {
  # 停止http_engine服务
  if grep -q "dbaas-lowcode-http-engine" ${configPath}/keeper.yaml;then
      if [[ -f ${installPath}/dbaas-lowcode-http-engine/stop.sh ]];then
        cd ${installPath}/dbaas-lowcode-http-engine
        ./stop.sh
        cd ${workdir}
      fi
      # 删除keeper.yaml的http服务
      __RemoveServiceFromKeeper "dbaas-lowcode-http-engine" ${configPath}/keeper.yaml
  fi
  # 去除readme中的http服务，是个幂等操作
  sed -i '/dbaas-lowcode-http-engine/d' ${installPath}/readme
  cd ${workdir}
  nodeNum=$( __ReadValue nodeconfig/installparam.txt nodeNum)
  if [[ ${installNodeType} == "OneNode" ]]; then
    infraIp=${hostIp}
  else
    infraIp=$( __readINI zcloud.cfg multiple consul.host )
  fi

  __QueryDatabaseInfo
  if [[  $( __readINI nodeconfig/current.cfg service low-code ) == ${nodeNum} ]]; then
    sed -i "s/self.webservice_ip = \"127.0.0.1\"/self.webservice_ip = \"${infraIp}\"/g" /usr/share/ansible/plugins/connection/zcloudAgent.py
    info "安裝低代码平台软件"
    __InitLowCodeConsulData

    __InitMagicCubeConsulData

    __InstallOpenWorkFlow

    __InstallDBaasLowcodeWorkFlow

    __InstallAnsibleExecutor

    __InstallMagicCube

    __InstallMagicScriptExecutor




    consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
    sed -i "s|#consulToken#|${consulToken}|g" ${configPath}/keeper.yaml
  else
    if [[ $(__readINI nodeconfig/current.cfg service low-code ) == ${nodeNum} ]];then
      if [[ ${databaseType} == "MySQL" ]];then
        mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
        ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} < other/hideLowCode.sql
      else
        ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -f other/hideLowCode.sql
      fi
    fi

    info "当前节点无需安装低代码"
  fi

}
function __InitLowCodeConsulData() {
  if [[ -f ${configPath}/consultoken.txt ]];then
    consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
    export CONSUL_HTTP_TOKEN=${consulToken}
    info "consulToken=${CONSUL_HTTP_TOKEN}"
  fi
  if [[ -f ${installPath}/soft/consul/consul/consul ]];then
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.api.excuter.url http://127.0.0.1:8915
    if [[ ${theme} == "zData" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url http://127.0.0.1:5002
    else
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url http://127.0.0.1:5000
    fi
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-lowcode-atomic-ability/database.name lowcodeworkflow
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/dbaas-management-database/lowcode.lcdpWorkflow.url ${localIP}:5001
    if [[ ${databaseType} = "MogDB" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.type mogdb
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.schema zcloud
    else
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.type mysql
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/database.schema lowcodeworkflow
    fi
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/task_management.host ${localIP}
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/lcdp-workflow-manager/dbaas_permissions.host ${localIP}
  else
    consulIp=$( __readINI zcloud.cfg multiple consul.host )
    if [[ ${consulToken} = "" ]];then
      curl -X PUT -d "http://127.0.0.1:8915" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.api.excuter.url?dc=dc1
      if [[ ${theme} == "zData" ]];then
        curl -X PUT -d "http://127.0.0.1:5002" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url?dc=dc1
      else
        curl -X PUT -d "http://127.0.0.1:5000" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url?dc=dc1
      fi
      curl -X PUT -d "lowcodeworkflow" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/database.name?dc=dc1
      curl -X PUT -d "${realHostIp}:5001" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-management-database/lowcode.lcdpWorkflow.url?dc=dc1
      if [[ ${databaseType} = "MogDB" ]];then
        curl -X PUT -d "mogdb" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.type?dc=dc1
        curl -X PUT -d "zcloud" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.schema?dc=dc1
      else
        curl -X PUT -d "mysql" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.type?dc=dc1
        curl -X PUT -d "lowcodeworkflow" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.schema?dc=dc1
      fi
      curl -X PUT -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/task_management.host?dc=dc1
      curl -X PUT -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/dbaas_permissions.host?dc=dc1
    else
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/task_management.host?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "http://127.0.0.1:8915" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.api.excuter.url?dc=dc1
      if [[ ${theme} == "zData" ]];then
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "http://127.0.0.1:5002" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url?dc=dc1
      else
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "http://127.0.0.1:5000" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/lowcode.atomic.ability.playbook.excuter.url?dc=dc1
      fi
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "lowcodeworkflow" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-lowcode-atomic-ability/database.name?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}:5001" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/dbaas-management-database/lowcode.lcdpWorkflow.url?dc=dc1
      if [[ ${databaseType} = "MogDB" ]];then
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "mogdb" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.type?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "zcloud" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.schema?dc=dc1
      else
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "mysql" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.type?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "lowcodeworkflow" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/database.schema?dc=dc1
      fi
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/task_management.host?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/dbaas_permissions.host?dc=dc1
    fi
  fi
}

function __InitMagicCubeConsulData() {
  __QueryDatabaseInfo
  if [[ -f ${configPath}/consultoken.txt ]];then
    consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
    export CONSUL_HTTP_TOKEN=${consulToken}
    info "consulToken=${CONSUL_HTTP_TOKEN}"
  fi
  if [[ -f ${installPath}/soft/consul/consul/consul ]];then
    # global
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/global.api_addr :18281
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/global.open_workflow_host ${localIP}
    # log
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/log.level info
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/log.dir ${homePath}/dbaas/zcloud-log/magic_cube
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/log.prefix magic-cube
    # database
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.debug false
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.auto_migrate_table false
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.host ${server_ip}
    ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.db_name lowcodeworkflow
    if [[ ${databaseType} = "MogDB" ]];then
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.type mogdb
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.port ${server_port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.schema zcloud
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.username ${dbaas_username}
    else
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.type mysql
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.port ${server_port}
      ${installPath}/soft/consul/consul/consul kv put zcloudconfig/prod/magic-cube/database.username ${dbaas_username}
    fi
  else
    consulIp=$( __readINI zcloud.cfg multiple consul.host )
    if [[ ${consulToken} = "" ]];then
      # global
      curl -X PUT -d ":18281" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/global.api_addr?dc=dc1
      curl -X PUT -d "${localIP}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/global.open_workflow_host?dc=dc1
      # log
      curl -X PUT -d "info" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/log.level?dc=dc1
      curl -X PUT -d "/home/zcloud/dbaas/zcloud-log/magic_cube" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/log.dir?dc=dc1
      curl -X PUT -d "magic-cube" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/log.prefix?dc=dc1
      # database
      curl -X PUT -d "false" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.debug?dc=dc1
      curl -X PUT -d "false" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.auto_migrate_table?dc=dc1
      curl -X PUT -d "${server_ip}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.host?dc=dc1
      curl -X PUT -d "lowcodeworkflow" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.db_name?dc=dc1
      if [[ ${databaseType} = "MogDB" ]];then
        curl -X PUT -d "mogdb" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.type?dc=dc1
        curl -X PUT -d "${server_port}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.port?dc=dc1
        curl -X PUT -d "zcloud" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.schema?dc=dc1
        curl -X PUT -d "${dbaas_username}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.username?dc=dc1
      else
        curl -X PUT -d "mysql" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.type?dc=dc1
        curl -X PUT -d "${server_port}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.port?dc=dc1
        curl -X PUT -d "${dbaas_username}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.username?dc=dc1
      fi
    else
      # global
      info "curl -X PUT -H \"X-Consul-Token: ${consulToken}\" -d \":18281\" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/global.api_addr?dc=dc1"
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d ":18281" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/global.api_addr?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${localIP}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/global.open_workflow_host?dc=dc1
      # log
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "error" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/log.level?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "/home/zcloud/dbaas/zcloud-log/magic_cube" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/log.dir?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "magic-cube" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/log.prefix?dc=dc1
      # database
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "false" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.debug?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "false" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.auto_migrate_table?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${server_ip}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.host?dc=dc1
      curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "lowcodeworkflow" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.db_name?dc=dc1
      if [[ ${databaseType} = "MogDB" ]];then
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "mogdb" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.type?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${server_port}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.port?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "zcloud" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.schema?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${dbaas_username}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.username?dc=dc1
      else
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "mysql" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.type?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${server_port}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.port?dc=dc1
        curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${dbaas_username}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/magic-cube/database.username?dc=dc1
      fi
    fi
  fi
}

function __InstallDBaasLowcodeWorkFlow {
  info ""
  cd jar
  info "开始安装 DBaas-Lowcode-WorkFlow"
  if [[ $(ps -ef|grep "gunicorn DBaasLowcodeWorkFlow.wsgi:application -b"|grep -v grep|wc -l) -gt 0 ]];then
    ps -ef |grep "gunicorn DBaasLowcodeWorkFlow.wsgi:application -b"|grep -v grep | awk '{print $2}' | xargs kill -9
    sleep 2s
  fi
  port=$(__ReadValue ${workdir}conf/port.cfg  "DBaas-Lowcode-WorkFlow" )
  __CreateDir ${logPath}/DBaas-Lowcode-WorkFlow
  #判断是否已解压
  if [[ -e ${installPath}/DBaas-Lowcode-WorkFlow ]]; then
    rm -rf ${installPath}/DBaas-Lowcode-WorkFlow
  fi
  if [[ ${installNodeType} == "OneNode" || ${nodeNum} == 1  ]]; then
    hostIp=$( __ReadValue ${workdir}nodeconfig/installparam.txt hostIp)
  else
    hostIp=$( __readINI ${workdir}zcloud.cfg multiple consul.host )
  fi

  cp -r DBaas-Lowcode-WorkFlow/ ${installPath}/DBaas-Lowcode-WorkFlow
  sed -ri "s|BASE_LOG_DIR =.*|BASE_LOG_DIR = \"${logPath}/DBaas-Lowcode-WorkFlow/\"|g" ${installPath}/DBaas-Lowcode-WorkFlow/DBaasLowcodeWorkFlow/settings/prod.py

  if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
    if [[ ! -d ${workdir}soft/ansible/ansible-install/ ]];then
      cd ${workdir}soft/ansible/
      tar -xf ansible-install.tar.gz
      cd ${workdir}
    fi
    \cp -rf ${workdir}soft/ansible/ansible-install/cffi-1.14.0-py3.9-linux-aarch64.egg ${installPath}/DBaas-Lowcode-WorkFlow/site-packages/
    rm -rf  ${installPath}/DBaas-Lowcode-WorkFlow/site-packages/psycopg2*
    if [[ -d ${installPath}/DBaas-Lowcode-WorkFlow/site-packages/Crypto/ ]];then
      rm -rf ${installPath}/DBaas-Lowcode-WorkFlow/site-packages/Crypto/
    fi

    if [[ -d ${installPath}/DBaas-Lowcode-WorkFlow/site-packages/pycrypto-2.6.1.dist-info/ ]];then
      rm -rf ${installPath}/DBaas-Lowcode-WorkFlow/site-packages/pycrypto-2.6.1.dist-info/
    fi
  fi
  export consulHost=${hostIp}
  export consulPort=8500
  export consulACLToken=${consulToken}
  if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "openEuler_x86" || ${osType}  = "bcLinux_arm" ]];then
    export LD_LIBRARY_PATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/arm/lib:/usr/lib64:$LD_LIBRARY_PATH
    export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/arm:${installPath}/DBaas-Lowcode-WorkFlow/site-packages
    info "export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/arm:${installPath}/DBaas-Lowcode-WorkFlow/site-packages"
    info "export LD_LIBRARY_PATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/arm/lib:/usr/lib64:$LD_LIBRARY_PATH"
  else
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/x86/CentOS-3.10.0-693-el7
    export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages
    info "export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages"
    info "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/x86/CentOS-3.10.0-693-el7"
  fi
  info "export consulHost=${hostIp}"
  info "export consulPort=8500"
  info "export consulACLToken=${consulToken}"



  #keeper 配置处理
  #删除以前的配置
  keeperConf=${configPath}/keeper.yaml
  while [[ `grep "serviceName: DBaas-Lowcode-WorkFlow.*"  ${keeperConf} |wc -l` -gt 0 ]]
  do
    serviceNameLine=`egrep -n  "serviceName: DBaas-Lowcode-WorkFlow.*" ${keeperConf}|awk -F':' '{print $1}'|head -1`
    offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
    sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
  done
  coreNum=`cat /proc/cpuinfo | grep 'processor'| wc -l`
  processNum=$[${coreNum}/8]
  if [[ ${processNum} == 0 ]];then
    processNum=1
  fi
  for((i=1;i<=${processNum};i++))
  do
    port=$[18080+i]
    __AddWorkFlowToKeeper ${port}
    info "${installPath}/DBaas-Lowcode-WorkFlow/bin/lowcodeworkflow_start.sh ${realHostIp}:${port}"
    ${installPath}/DBaas-Lowcode-WorkFlow/bin/lowcodeworkflow_start.sh ${realHostIp}:${port}
    if [[ ${databaseType} = "MogDB" ]];then
      export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib:$LD_LIBRARY_PATH
      ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='${port}'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \"type\", metrics_path, description)VALUES('DBaas-Lowcode-WorkFlow', '${realHostIp}', '${port}', 'service', '/lcdpWorkflow/workflow/healthcheck', '作业流服务');" >> ${logFile} 2>&1
    else
      mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
      ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} mysql -e "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='${port}'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \`type\`, metrics_path, description)VALUES('DBaas-Lowcode-WorkFlow', '${realHostIp}', '${port}', 'service', '/lcdpWorkflow/workflow/healthcheck', '作业流服务');" >> ${logFile} 2>&1
    fi
  done
  if [[ ${databaseType} = "MogDB" ]];then
    export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib:$LD_LIBRARY_PATH
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "update lowcodeworkflow.workflow_lowcodedict set value='$[processNum*16]' where name='resource_unit_concurrency_threshold';" >> ${logFile} 2>&1
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from lowcodeworkflow.lowcode_global_config where config_key ='ATOMIC_ABILITY_THREADPOOL_MAXIMUM';INSERT INTO lowcodeworkflow.lowcode_global_config(config_key, config_value, create_time, update_time, comfig_remark)VALUES('ATOMIC_ABILITY_THREADPOOL_MAXIMUM', '$[processNum*48]', '2023-02-15 16:25:14.000', '2023-02-15 16:25:14.000', '原子能力最大并发数');" >> ${logFile} 2>&1
  else
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} mysql -e "update lowcodeworkflow.workflow_lowcodedict set value='$[processNum*16]' where name='resource_unit_concurrency_threshold';" >> ${logFile} 2>&1
    ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} mysql -e "delete from lowcodeworkflow.lowcode_global_config where config_key ='ATOMIC_ABILITY_THREADPOOL_MAXIMUM';INSERT INTO lowcodeworkflow.lowcode_global_config(config_key, config_value, create_time, update_time, comfig_remark)VALUES('ATOMIC_ABILITY_THREADPOOL_MAXIMUM', '$[processNum*48]', '2023-02-15 16:25:14.000', '2023-02-15 16:25:14.000', '原子能力最大并发数');" >> ${logFile} 2>&1
  fi
  cd ${workdir}
  cp script/other/start.sh ${installPath}/DBaas-Lowcode-WorkFlow
  cp script/other/stop.sh ${installPath}/DBaas-Lowcode-WorkFlow


  info "DBaas-Lowcode-WorkFlow 安装完成 "
}


function __InstallAnsibleExecutor {
  info ""
  cd ${workdir}jar
  info "开始安装 ansible_executor"
  if [[ ${osType}  = "openEuler_x86" || ${osType}  = "openEuler_arm"  || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm"  ]];then
    if [[ $(ps -ef|grep "python3.9_enmo ${installPath}/ansible_executor/ansible_executor.py"|grep -v grep|wc -l) -gt 0 ]];then
      ps -ef |grep "python3.9_enmo ${installPath}/ansible_executor/ansible_executor.py"|grep -v grep | awk '{print $2}' | xargs kill -9
      sleep 2s
    fi
  else
    if [[ $(ps -ef|grep "python3.9 ${installPath}/ansible_executor/ansible_executor.py"|grep -v grep|wc -l) -gt 0 ]];then
      ps -ef |grep "python3.9 ${installPath}/ansible_executor/ansible_executor.py"|grep -v grep | awk '{print $2}' | xargs kill -9
      sleep 2s
    fi
  fi
  port=$(__CheckPort ansible_executor)
  if [[ ${port} -gt 0 ]];then
    if [[ ${installType} != 4 ]];then
      error "${port}端口已被占用，ansible_executor安装失败,安装中断"
      exit 1
    fi
  fi
  __CreateDir ${logPath}/ansible_executor
  #判断是否已解压
  if [[ -d ${installPath}/ansible_executor ]]; then
    rm -rf ${installPath}/ansible_executor
  fi
  cp -r ansible_executor/ ${installPath}/ansible_executor

  if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
    if [[ ! -d ${workdir}soft/ansible/ansible-install/ ]];then
      cd ${workdir}soft/ansible/
      tar -xf ansible-install.tar.gz
      cd ${workdir}
    fi
    \cp -rf ${workdir}soft/ansible/ansible-install/cffi-1.14.0-py3.9-linux-aarch64.egg ${installPath}/ansible_executor/site-packages/
    rm -rf  ${installPath}/ansible_executor/site-packages/psycopg2*
    if [[ -d ${installPath}/ansible_executor/site-packages/Crypto/ ]];then
      rm -rf ${installPath}/ansible_executor/site-packages/Crypto/
    fi

    if [[ -d ${installPath}/ansible_executor/site-packages/pycrypto-2.6.1.dist-info/ ]];then
      rm -rf ${installPath}/ansible_executor/site-packages/pycrypto-2.6.1.dist-info/
    fi
  fi
  PATH=/usr/local/Python3.9/bin:$PATH
  if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
    export PYTHONPATH=${installPath}/ansible_executor/site-packages/shared-lib/arm:${installPath}/ansible_executor/site-packages
    export LD_LIBRARY_PATH=${installPath}/ansible_executor/site-packages/shared-lib/arm/lib:/usr/lib64:$LD_LIBRARY_PATH
  else
    export PYTHONPATH=${installPath}/ansible_executor/site-packages
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64:${installPath}/ansible_executor/site-packages/shared-lib/x86/CentOS-3.10.0-693-el7
  fi
  if [[ ${theme} == "zData" ]];then
    sed -i "s|app.run(host='0.0.0.0', threaded=True)|app.run(host='0.0.0.0',port=5002, threaded=True)|g" ${installPath}/ansible_executor/ansible_executor.py
  fi

  if [[ ${osType}  = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm" ]];then

    info "nohup python3.9_enmo ${installPath}/ansible_executor/ansible_executor.py --consulHost=${hostIp} --consulACLToken=${consulToken} --logpath=${installPath}/ansible_executor/ansible_executor.log --consulPort=8500 >/dev/null  2>&1 &"
    nohup python3.9_enmo ${installPath}/ansible_executor/ansible_executor.py --consulHost=${hostIp} --consulACLToken=${consulToken} --logpath=${logPath}/ansible_executor/ansible_executor.log --consulPort=8500 >/dev/null 2>&1 &
    keeperConf=${configPath}/keeper.yaml
    if ! grep -q "python3.9_enmo" ${keeperConf}; then
    sed -i "s/python3.9/python3.9_enmo/g" ${keeperConf}
    fi
  else
    info "nohup python3.9 ${installPath}/ansible_executor/ansible_executor.py --consulHost=${hostIp} --consulACLToken=${consulToken} --logpath=${installPath}/ansible_executor/ansible_executor.log --consulPort=8500 >/dev/null  2>&1 &"
    nohup python3.9 ${installPath}/ansible_executor/ansible_executor.py --consulHost=${hostIp} --consulACLToken=${consulToken} --logpath=${logPath}/ansible_executor/ansible_executor.log --consulPort=8500 >/dev/null 2>&1 &
  fi
  cd ${workdir}
  cp script/other/start.sh ${installPath}/ansible_executor
  cp script/other/stop.sh ${installPath}/ansible_executor
  if [[ ${installType} = 4 ]];then
    __AddToKeeper "ansible_executor"
  fi
  if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
    sed -i "s|PYTHONPATH=${installPath}/ansible_executor/site-packages|PYTHONPATH=${installPath}/ansible_executor/site-packages/shared-lib/arm:${installPath}/ansible_executor/site-packages|g" ${configPath}/keeper.yaml
    sed -i "s|LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${installPath}/ansible_executor/site-packages/shared-lib/x86/CentOS-3.10.0-693-el7|LD_LIBRARY_PATH=${installPath}/ansible_executor/site-packages/shared-lib/arm/lib:/usr/lib64:\$LD_LIBRARY_PATH|g" ${configPath}/keeper.yaml
  fi
  port1=5000
  if [[ ${theme} == "zData" ]];then
    port1=5002
  fi
  if [[ ${databaseType} = "MogDB" ]];then
    export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib:$LD_LIBRARY_PATH
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='${port1}'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \"type\", metrics_path, description)VALUES('ansible_executor', '${realHostIp}', '${port1}', 'service', '/healthcheck', 'ansible执行器');" >> ${logFile} 2>&1
  else
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} mysql -e "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='${port1}'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \`type\`, metrics_path, description)VALUES('ansible_executor', '${realHostIp}', '${port1}', 'service', '/healthcheck', 'ansible执行器');" >> ${logFile} 2>&1
  fi


  info "ansible_executor 安装完成"
}

function __InstallOpenWorkFlow {
  cd jar
  info "开始安装 open_workflow"
  if [[ $(ps -ef|grep "${installPath}/open_workflow/open_workflow --conf="|grep -v grep|wc -l) -gt 0 ]];then
    ps -ef |grep "${installPath}/open_workflow/open_workflow --conf="|grep -v grep | awk '{print $2}' | xargs kill -9
    sleep 2s
  fi
  port=$(__CheckPort open_workflow)
  if [[ ${port} -gt 0 ]];then
    error "${port}端口已被占用，open_workflow安装失败,安装中断"
    exit 1
  fi
  #判断是否已解压
  if [[ -d ${installPath}/open_workflow ]]; then
    rm -rf ${installPath}/open_workflow
  fi
  cp -r open_workflow/ ${installPath}/open_workflow
  if [[ ${databaseType} == MogDB ]];then
    sed -ri "s|type:.*|type: \"mogdb\"|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  fi
  sed -ri "s|user:.*|user: \"${dbaas_username}\"|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  sed -ri "s|pwd:.*|pwd: \"${dbaas_paasword_encode}\"|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  sed -ri "s|host:.*|host: \"${server_ip}\"|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  sed -ri "s|port:.*|port: ${server_port}|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  sed -ri "s|addr: \"127.0.0.1:8088\"|addr: \"${hostIp}:8088\"|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  sed -ri "s|addr: \"127.0.0.1:18080\"|addr: \"${hostIp}:18080\"|g" ${installPath}/open_workflow/conf/open_workflow.yaml
  __CreateDir ${logPath}/open_workflow
  info "nohup ${installPath}/open_workflow/open_workflow --conf=${installPath}/open_workflow/conf/open_workflow.yaml --log.filename=${installPath}/open_workflow/open_workflow.log --log.level=info --log.maxsize=32  --log.backlog=7 >/dev/null 2>&1 &"
  nohup ${installPath}/open_workflow/open_workflow --conf=${installPath}/open_workflow/conf/open_workflow.yaml --log.filename=${logPath}/open_workflow/open_workflow.log --log.level=info --log.maxsize=32  --log.backlog=7 >/dev/null 2>&1 &
  cd ${workdir}
  cp script/other/start.sh ${installPath}/open_workflow
  cp script/other/stop.sh ${installPath}/open_workflow
  if [[ ${installType} = 4 ]];then
    __AddToKeeper "open_workflow"
  fi
  consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
  if [[ ${installNodeType} == "OneNode" ]]; then
    consulIp=${hostIp}
  else
    consulIp=$( __readINI zcloud.cfg multiple consul.host )
  fi
  curl -X PUT -H "X-Consul-Token: ${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/open_workflow.host?dc=dc1
  if [[ ${databaseType} = "MogDB" ]];then
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='5001'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \"type\", metrics_path, description)VALUES('open_workflow', '${realHostIp}', '5001', 'service', '/health/check', '开放作业中心');" >> ${logFile} 2>&1
  else
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} mysql -e "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='5001'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \`type\`, metrics_path, description)VALUES('open_workflow', '${realHostIp}', '5001', 'service', '/health/check', '开放作业中心');" >> ${logFile} 2>&1
  fi
  info "open_workflow 安装完成"
}

function __InstallMagicCube {
  cd jar
  info "开始安装 magic_cube"
  if [[ $(ps -ef|grep "${installPath}/magic_cube/magic_cube --consul.endpoint"|grep -v grep|wc -l) -gt 0 ]];then
    ps -ef |grep "${installPath}/magic_cube/magic_cube --consul.endpoint"|grep -v grep | awk '{print $2}' | xargs kill -9
    sleep 2s
  fi
  port=$(__CheckPort magic_cube)
  if [[ ${port} -gt 0 ]];then
    error "${port}端口已被占用，magic_cube安装失败,安装中断"
    exit 1
  fi
  #判断是否已解压
  if [[ -d ${installPath}/magic_cube ]]; then
    rm -rf ${installPath}/magic_cube
  fi
  cp -r magic_cube/ ${installPath}/magic_cube
  __CreateDir ${logPath}/magic_cube
  consulToken=`less ${configPath}/consultoken.txt | grep SecretID|awk '{print $2}'`
  if [[ ${installNodeType} == "OneNode" ]]; then
    consulIp=${hostIp}
  else
    consulIp=$( __readINI ${workdir}zcloud.cfg multiple consul.host )
  fi
  info "nohup ${installPath}/magic_cube/magic_cube --consul.endpoint=http://${consulIp}:8500 --consul.token=${consulToken} >/dev/null 2>&1 &"
  nohup ${installPath}/magic_cube/magic_cube --consul.endpoint=http://${consulIp}:8500 --consul.token=${consulToken} >/dev/null 2>&1 &
  cd ${workdir}
  cp script/other/start.sh ${installPath}/magic_cube
  cp script/other/stop.sh ${installPath}/magic_cube
  if [[ ${installType} = 4 ]];then
    __AddToKeeper "magic_cube"
  fi

  if [[  ( ${osType} = "RedHat"  ||  ${osType} = "Oracle"  ) && ${osVersion} == 8.* ]] || [[ ${osType}  = "openEuler_arm" || ${osType}  = "openEuler_x86" || ${osType}  = "bcLinux_arm" || ${osType}  = "bcLinux_x86"  || ${osType}  = "Kylin_arm"  ]]; then
      export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
  fi

  info "curl -X PUT -H "X-Consul-Token:${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/magic_cube_host?dc=dc1"
  curl -X PUT -H "X-Consul-Token:${consulToken}" -d "${realHostIp}" http://${consulIp}:8500/v1/kv/zcloudconfig/prod/lcdp-workflow-manager/magic_cube_host?dc=dc1
  if [[ ${databaseType} = "MogDB" ]];then
    export LD_LIBRARY_PATH=${installPath}/soft/mogdb/app/lib:$LD_LIBRARY_PATH
    ${installPath}/soft/mogdb/app/bin/gsql -d zcloud -h ${server_ip} -p ${server_port} -U ${dbaas_username} -W ${dbaas_password} -c "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='18281'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \"type\", metrics_path, description)VALUES('magic-cube', '${realHostIp}', '18281', 'service', '/health/check', '开放作业中心');" >> ${logFile} 2>&1
  else
    mysqlAddr="${installPath}/soft/mysql/mysql/bin/mysql"
    ${mysqlAddr} -uroot -p${dbaas_password} -h${server_ip} -P${server_port} mysql -e "delete from monitormanager.zcloud_platform_component where ip='${realHostIp}' and port='18281'; INSERT INTO monitormanager.zcloud_platform_component(name, ip, port, \`type\`, metrics_path, description)VALUES('magic-cube', '${realHostIp}', '18281', 'service', '/health/check', '开放作业中心');" >> ${logFile} 2>&1
  fi
  info "magic_cube 安装完成"
}

function __AddToKeeper {
  serviceName=$1
  keeperConf=${configPath}/keeper.yaml
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${keeperConf}`
  offset=`sed -n "$[${serviceNameLine}+1],\$"p ${keeperConf} |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
  if [[ ${serviceNameLine} != "" ]];then
    sed -i "${serviceNameLine},$[${serviceNameLine}+${offset}]d" ${keeperConf}
  fi
  serviceNameLine=`sed -n "/serviceName: ${serviceName}\$/=" ${workdir}conf/keeper.yaml`
  offset=`sed -n "$[${serviceNameLine}+1],\$"p ${workdir}conf/keeper.yaml |grep -n defaultProcessNum:|head -n 1|awk -F':' '{print $1}'`
  if [[ ${serviceNameLine} != "" ]];then
    sed -n "${serviceNameLine},$[${serviceNameLine}+${offset}]p" ${workdir}conf/keeper.yaml>temp.yaml
    endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
    sed -i "${endLine}r temp.yaml" ${keeperConf}
    rm -f temp.yaml
    sed -i "s|#installPath#|${installPath}|g" ${keeperConf}
    sed -i "s|#localIP#|${hostIp}|g" ${keeperConf}
    sed -i "s|#logPath#|${logPath}|g" ${keeperConf}
    sed -i "s|#consulToken#|${consulToken}|g" ${keeperConf}
  fi
}

function __AddWorkFlowToKeeper {
  port=$1
  keeperConf=${configPath}/keeper.yaml

  if [[ ${osType}  == "Kylin_arm" || ${osType}  = "uos_arm" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_arm" ]];then
    echo "- serviceName: DBaas-Lowcode-WorkFlow-${port}
  path: gunicorn DBaasLowcodeWorkFlow.wsgi:application -b ${realHostIp}:${port}
  prefix: export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/arm:${installPath}/DBaas-Lowcode-WorkFlow/site-packages;export
      consulHost=${hostIp};export consulPort=8500;export consulACLToken=${consulToken};export
      LD_LIBRARY_PATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/arm/lib:/usr/lib64:\$LD_LIBRARY_PATH;
  suffix: cd ${installPath}/DBaas-Lowcode-WorkFlow;bin/lowcodeworkflow_start.sh
      ${realHostIp}:${port}
  enable: true
  defaultProcessNum: 2">temp.yaml
  else
    if [[ -f /usr/lib64/libpq.so.5 ]];then
    echo "- serviceName: DBaas-Lowcode-WorkFlow-${port}
  path: gunicorn DBaasLowcodeWorkFlow.wsgi:application -b ${realHostIp}:${port}
  prefix: export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages;export
      consulHost=${hostIp};export consulPort=8500;export consulACLToken=${consulToken};export
      LD_LIBRARY_PATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/x86/CentOS-3.10.0-693-el7:/usr/lib64:\$LD_LIBRARY_PATH;
  suffix: cd ${installPath}/DBaas-Lowcode-WorkFlow;bin/lowcodeworkflow_start.sh
      ${realHostIp}:${port}
  enable: true
  defaultProcessNum: 2">temp.yaml
    else
    echo "- serviceName: DBaas-Lowcode-WorkFlow-${port}
  path: gunicorn DBaasLowcodeWorkFlow.wsgi:application -b ${realHostIp}:${port}
  prefix: export PYTHONPATH=${installPath}/DBaas-Lowcode-WorkFlow/site-packages;export
      consulHost=${hostIp};export consulPort=8500;export consulACLToken=${consulToken};export
      LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64:${installPath}/DBaas-Lowcode-WorkFlow/site-packages/shared-lib/x86/CentOS-3.10.0-693-el7;
  suffix: cd ${installPath}/DBaas-Lowcode-WorkFlow;bin/lowcodeworkflow_start.sh
      ${realHostIp}:${port}
  enable: true
  defaultProcessNum: 2">temp.yaml
    fi
  fi
  endLine=`awk '{print NR}' ${keeperConf} |tail -n1`
  sed -i "${endLine}r temp.yaml" ${keeperConf}
  rm -f temp.yaml
}


function __preparePythonSource {
  mkdir -p /paasdata/python/2.7.5/source/centos7
  \cp ${workdir}/soft/pysrc/pip-20.3.4.tar.gz /paasdata/python/2.7.5/source/centos7
  \cp ${workdir}/soft/pysrc/setuptools-41.6.0.tar.gz /paasdata/python/2.7.5/source/centos7
  \cp ${workdir}/soft/pysrc/Python-2.7.5.tar.xz /paasdata/python/2.7.5/source/centos7
  if [[ ! -d /paasdata/python/compiledPythonPkg ]];then
    mkdir -p /paasdata/python/compiledPythonPkg
  fi
  \cp ${workdir}/soft/compiledPythonPkg/* /paasdata/python/compiledPythonPkg
  chown -R zcloud:zcloud /paasdata/
}

function __preparePythonPip2pi {
  # 如果pip2pi已经安装, 不重复安装
  set +e
  isPip2piInstalled=$(pip3.9 list|grep pip2pi)
  retCode=$?
  if [[ ${osType} = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm" ]];then
      isPip2piInstalled=$(pip3.9_enmo list|grep pip2pi)
      retCode=$?
  fi
  if [ ${retCode} -eq 1 ]
  then
    if [[ ${osType} = "openEuler_x86" || ${osType}  = "openEuler_arm" || ${osType}  = "bcLinux_x86" || ${osType}  = "bcLinux_arm"  ]];then
        info "pip3.9_enmo install --no-index ${workdir}/soft/pysrc/pip2pi-0.8.2.tar.gz"
        pip3.9_enmo install --no-index ${workdir}/soft/pysrc/pip2pi-0.8.2.tar.gz
    else
        info "pip3.9 install --no-index ${workdir}/soft/pysrc/pip2pi-0.8.2.tar.gz"
        pip3.9 install --no-index ${workdir}/soft/pysrc/pip2pi-0.8.2.tar.gz
    fi
    chmod -R 755 /usr/local/Python3.9/lib/python3.9/site-packages/
  fi
  set -e
  mkdir -p /paasdata/python/2.7.5/pypi
  /usr/local/Python3.9/bin/dir2pi /paasdata/python/2.7.5/pypi
  chown -R zcloud:zcloud /paasdata/python/2.7.5/pypi
}

function __prepareAnsibleModule {
  mkdir -p /usr/share/ansible/plugins/modules
  \cp -f soft/ansible/*.py /usr/share/ansible/plugins/modules
  chown -R zcloud:zcloud /usr/share/ansible/plugins/modules
}


__InstallLowCodeEnv