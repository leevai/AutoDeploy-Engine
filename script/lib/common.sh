bold=$(tput bold)
reset=$(tput sgr0)
red=$(tput setaf 1)
white=$(tput setaf 7)
underline=$(tput sgr 0 1)

function __ReplaceText() {
    typeset -r fileNmae=${1}
    typeset -r oldText=${2}
    typeset -r newText=${3}
    sed -i "/${oldText}*/d" ${fileNmae}
    echo ""                                         >> ${fileNmae}
    echo "${newText}"                               >> ${fileNmae}
    # sed -i "s|${oldText}|${newText}|g" ${fileNmae}  &>> install.log
}

function __ReadValue() {
    typeset -r fileName=${1}
    typeset -r key=${2}
    echo `cat ${fileName} |grep ${key}|awk -F'=' '{print $NF}'`
}

function error() {
    printf "${red}✖ [zcloud dbaas] %s${reset}\n" "$@"
    if [[ -f ${logFile} ]];then
      echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
    fi
}

function info() {
     printf "${white}➜ [zcloud dbaas] %s${reset}\n" "$@"
     if [[ -f ${logFile} ]];then
       echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
     fi

}

function __ReplaceTextSed() {
    typeset -r fileNmae=${1}
    typeset -r oldText=${2}
    typeset -r newText=${3}
    sed -i "s|${oldText}|${newText}|g"      ${fileNmae}
}

function __readINI() {
    INIFILE=$1;
    SECTION=$2;
    ITEM=$3
    _readIni=`cat $INIFILE|awk -vsection="[$SECTION]" 'begin{isprint=0}{if($0~/^\[.*/ ){if($0==section){isprint=1} else {isprint=0}}else{ if(isprint==1){print $0}}}'|egrep "^$ITEM\s*="|sed 's/=/::/'|awk -F'::' '{print $NF}'`
    echo ${_readIni}
}

function __CheckPort() {
  ssPath=`which ss`
  typeset -r serviceName=${1}
  port=$(__ReadValue ${workdir}/conf/port.cfg  "${serviceName}=" )
  if [[ ${serviceName} = "nginx" ]];then
    port=${ui_url_port}
  fi
  if [[ ${port} = "" ]];then
    echo 0
  else
    if [[ `${ssPath} -tlnp|awk '{print $4}' | grep -w ${port}|wc -l` -gt 0 ]];then
      echo ${port}
    else
      echo 0
    fi
  fi
}

function h2() {
    printf "\n${underline}${bold}${white}[zcloud dbaas] %s${reset}\n" "$@"
    if [[ -f ${logFile} ]];then
      echo "[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")]$@">> ${logFile}
    fi
}

function __CalcDuration {
  startTime=$1
  endTime=$2
  duration=$[(${endTime}-${startTime})/1000000]
  if [[ ${duration} -lt 1000 ]];then
    echo "${duration}ms"
  elif [[ ${duration} -lt 60000 ]]; then
    echo "$[${duration}/1000]s"
  else
    echo "$[${duration}/60000]m"
  fi
}