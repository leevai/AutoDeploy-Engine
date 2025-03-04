
reset=$(tput sgr0)
red=$(tput setaf 1)

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