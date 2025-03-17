#!/bin/bash

installPath=#{installPath}
workdir=#{workdir}
theme=#{theme}


function __cpSys {
    cd ${workdir}
    \cp -f paasdata/sys.tar.gz ${installPath}/packages/download
    cd ${installPath}/packages/download
    tar -xf sys.tar.gz
    cd ${workdir}
}


if [[ ${theme} != 'zData' ]]; then
    __cpSys
fi