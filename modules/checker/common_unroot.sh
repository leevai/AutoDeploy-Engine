#!/usr/bin/env bash
set +e
set -o noglob

#
# Set Colors
#

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 76)
white=$(tput setaf 7)
tan=$(tput setaf 202)
blue=$(tput setaf 25)

#
# Headers and Logging
#
#  underline /tmp/20171031/docker/dbaas-activiti.tar
function underline() {
    printf "${underline}${bold}[zcloud dbaas] %s${reset}\n" "$@"
}

#  h1        /tmp/20171031/docker/dbaas-activiti.tar
function h1() {
    printf "\n${underline}${bold}${blue}[zcloud dbaas] %s${reset}\n" "$@"
    echo "[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")]$@">> ${logFile}
}

#  h2        /tmp/20171031/docker/dbaas-activiti.tar
function h2() {
    printf "\n${underline}${bold}${white}[zcloud dbaas] %s${reset}\n" "$@"
    if [[ -f ${logFile} ]];then
      echo "[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")]$@">> ${logFile}
    fi
}
function h3() {
    printf "\n${underline}${bold}${white}[zcloud dbaas] %s${reset}\n" "$@"
}
#  debug     /tmp/20171031/docker/dbaas-activiti.tar
function debug() {
    printf "${white}[zcloud dbaas] %s${reset}\n" "$@"
}

# ➜  info      /tmp/20171031/docker/dbaas-activiti.tar
function info() {
     printf "${white}➜ [zcloud dbaas] %s${reset}\n" "$@"
     if [[ -f ${logFile} ]];then
       echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
     fi

}

# ➜  info      /tmp/20171031/docker/dbaas-activiti.tar
function wl() {
     printf "${white} %s${reset}\n" "$@"
}

# ✔  success   /tmp/20171031/docker/dbaas-activiti.tar
function success() {
    printf "${green}✔ [zcloud dbaas] %s${reset}\n" "$@"
    echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
}

# ✖  error     /tmp/20171031/docker/dbaas-activiti.tar
function error() {
    printf "${red}✖ [zcloud dbaas] %s${reset}\n" "$@"
    if [[ -f ${logFile} ]];then
      echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
    fi
}

# ➜  warn      /tmp/20171031/docker/dbaas-activiti.tar
function warn() {
    printf "${tan}➜ [zcloud dbaas] %s${reset}\n" "$@"
    echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
}

#  bold      /tmp/20171031/docker/dbaas-activiti.tar
function bold() {
    printf "${bold}[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] %s${reset}\n" "$@"
    echo "  ➜[zcloud dbaas] $@">> ${logFile}
}

# Note:  note      /tmp/20171031/docker/dbaas-activiti.tar
function note() {
    printf "\n${underline}${bold}${blue}Note:${reset} ${blue}[zcloud dbaas] %s${reset}\n" "$@"
    echo "  ➜[zcloud dbaas][$(date "+%Y-%m-%d %H:%M:%S")] $@">> ${logFile}
}

set -e
set +o noglob


function __readINI() {
    INIFILE=$1;
    SECTION=$2;
    ITEM=$3
    _readIni=`cat $INIFILE|awk -vsection="[$SECTION]" 'begin{isprint=0}{if($0~/^\[.*/ ){if($0==section){isprint=1} else {isprint=0}}else{ if(isprint==1){print $0}}}'|egrep "^$ITEM\s*="|sed 's/=/::/'|awk -F'::' '{print $NF}'`
    echo ${_readIni}
}

function __ReplaceText() {
    typeset -r fileNmae=${1}
    typeset -r oldText=${2}
    typeset -r newText=${3}
    sed -i "/${oldText}*/d" ${fileNmae}
    echo ""                                         >> ${fileNmae}
    echo "${newText}"                               >> ${fileNmae}
    # sed -i "s|${oldText}|${newText}|g" ${fileNmae}  &>> install.log
}

function __ReplaceTextSed() {
    typeset -r fileNmae=${1}
    typeset -r oldText=${2}
    typeset -r newText=${3}
    sed -i "s|${oldText}|${newText}|g"      ${fileNmae}
}

function __ReadValue() {
    typeset -r fileName=${1}
    typeset -r key=${2}
    echo `cat ${fileName} |grep ${key}|awk -F'=' '{print $NF}'`
}

function __CheckPort() {
  typeset -r serviceName=${1}
  port=$(__ReadValue ${workdir}conf/port.cfg  "${serviceName}=" )
  if [[ ${serviceName} = "nginx" ]];then
    ui_url_port=($( __readINI zcloud.cfg web "ui_url_port" ))
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