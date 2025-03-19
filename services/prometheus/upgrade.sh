. ./script/lib/soft_bak.sh
. ./script/lib/common.sh
installPath=#{installPath}
configPath=#{configPath}
installType=#{installType}
outsidePrometheus=#{outsidePrometheus}
keeperConf=#{keeperConf}
workdir=#{workdir}

h2 "[Step $item/$stepTotal]:  备份prometheus配置 ..."; let item+=1
startTime=$(date +"%s%N")
__BackUpPrometheusConf
endTime=$(date +"%s%N")
info "备份prometheus配置完成，耗时$( __CalcDuration ${startTime} ${endTime})"

h2 "[Step $item/$stepTotal]:  停止prometheus服务 ..."; let item+=1
startTime=$(date +"%s%N")
__StopPrometheus
endTime=$(date +"%s%N")
info "更改prometheus服务完成，耗时$( __CalcDuration ${startTime} ${endTime})"