
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

function __readINI() {
    INIFILE=$1;
    SECTION=$2;
    ITEM=$3
    _readIni=`cat $INIFILE|awk -vsection="[$SECTION]" 'begin{isprint=0}{if($0~/^\[.*/ ){if($0==section){isprint=1} else {isprint=0}}else{ if(isprint==1){print $0}}}'|egrep "^$ITEM\s*="|sed 's/=/::/'|awk -F'::' '{print $NF}'`
    echo ${_readIni}
}