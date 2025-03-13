installPath=#{installPath}
workdir=#{workdir}


. ./script/lib/dir_auth.sh

function __MovePubLib() {
    if [[ -d ${installPath}/pub_libs ]];then
      if [[ -d  ${installPath}/pub_libs_bak_$(date '+%Y%m%d') ]];then
        rm -rf  ${installPath}/pub_libs_bak_$(date '+%Y%m%d')
      fi
      mv  ${installPath}/pub_libs ${installPath}/pub_libs_bak_$(date '+%Y%m%d')
    fi
    __CreateDir ${installPath}/pub_libs
    \cp -fr ${workdir}/jar/pub_libs/* ${installPath}/pub_libs
    if [[ -f  ${installPath}/pub_libs/repository/com/enmo/dbaas/dbaas-zcloud-feign/6.6.0-SNAPSHOT/_remote.repositories ]];then
      rm -f ${installPath}/pub_libs/repository/com/enmo/dbaas/dbaas-zcloud-feign/6.6.0-SNAPSHOT/_remote.repositories
    fi
}

__MovePubLib