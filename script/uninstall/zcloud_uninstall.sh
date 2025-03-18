
homePath=`su - zcloud -c "pwd"`

su - zcloud -c "cd ${homePath}/dbaas/soft-install/magic-script-executor;./stop.sh"

mergedPoint=$(mount | grep podman | grep overlay | grep '/merged' | awk '{print $3}')
[ -n "$mergedPoint" ] && umount $mergedPoint

shmPoint=$(mount | grep podman | grep overlay | grep '/shm' | awk '{print $3}')
[ -n "$shmPoint" ] && umount $shmPoint

${homePath}/dbaas/soft-install/podman/podman --runtime ${homePath}/dbaas/soft-install/podman/runc rm -f magic-script-executor

ps -ef|grep nginx|grep master |grep -v proxy  | awk '{print $2}' | xargs kill -15

ps -ef|grep /dbaas/|grep -v grep   | awk '{print $2}'| xargs kill -9

rm -rf ${homePath}/dbaas

rm -rf ${homePath}/.influxdbv2

rm -rf /tmp/upload/
#如果以前安装过mogdb 才执行
if [[ -d ${homePath}/dbaas/soft-install/soft/mogdb ]];then
  ptk uninstall -n zcloud_cluster --skip-confirm --remove-data y --remove-user n
fi

#卸载proxy
if [[ -d /home/proxy ]];then
  /zcloud/proxy/proxyOperate.sh proxyAgentServer uninstall
fi

