#!/bin/bash
######################################################################
# version:1
# author: wanglicheng
# created:20220526
# update:
######################################################################
export LANG=en_US.utf8
function __InstallKeeperMonitor {
  if [[ ${installType} != 4 ]];then
  echo "
  #!/bin/bash
  ######################################################################
  # version:1
  # author: wanglicheng
  # created:20220526
  # update:
  ######################################################################
  export LANG=en_US.utf8

  if [[ -f /sys/devices/virtual/dmi/id/product_serial  ]];then
    chmod o+r /sys/devices/virtual/dmi/id/product_serial
  fi
  if [[ -f /sys/devices/virtual/dmi/id/board_serial  ]];then
    chmod o+r /sys/devices/virtual/dmi/id/board_serial
  fi
  if [[ -f /sys/firmware/dmi/tables/smbios_entry_point  ]];then
    chmod o+r /sys/firmware/dmi/tables/smbios_entry_point
  fi

  if [[ -f /dev/mem ]];then
    chmod o+r /dev/mem
  fi

  if [[ -f /sys/firmware/dmi/tables/DMI ]];then
    chmod o+r /sys/firmware/dmi/tables/DMI
  fi

  while true; do
   datestr=\$(date \"+%Y-%m-%d %H:%M:%S\")
   zcloud_home_dir=\$(cat /etc/passwd|egrep ^zcloud:|awk -F':' '{print \$(NF-1)}')
   if [ -z \$zcloud_home_dir ]; then
      echo \"\$datestr: not found zcloud user\";
      sleep 60;continue;
   fi
   if [ ! -f \${zcloud_home_dir}/zcloud/proxy/notRootMonitor/monitorOperate.sh ];
       then echo \"\$datestr:monitorOperate start script file \${zcloud_home_dir}/zcloud/proxy/notRootMonitor/monitorOperate.sh is not exists\";
   else
    proxyMonitorStatus=\`sh \${zcloud_home_dir}/zcloud/proxy/notRootMonitor/monitorOperate.sh status\`
    if [ \$proxyMonitorStatus -eq 0 ];
         then echo \"\$datestr: proxyMonitor already started\";
      else
         su - zcloud -c \"sh \${zcloud_home_dir}/zcloud/proxy/notRootMonitor/monitorOperate.sh restart\"
         echo \"\$datestr: monitorOperate started success\";
    fi
   fi
   keepercnt=\$(ps -ef|grep zcloud-keeper|grep -v grep |wc -l)
   if [ \$keepercnt -gt 0 ];
       then echo \"\$datestr: zcloud-keeper already started;\"
   elif [ -f \"\${zcloud_home_dir}/dbaas/soft-install/keeper/script/startkeeper.sh\" ]; then
      su - zcloud -c \"sh \${zcloud_home_dir}/dbaas/soft-install/keeper/script/startkeeper.sh\"
      if [ \$? -gt 0 ]; then echo \"\$datestr:ERROR found: starting startkeeper.sh\"; sleep 60; continue; fi
      echo \"\$datestr: keeper started success\";
   else echo \"\$datestr: ERROR:\${zcloud_home_dir}/dbaas/soft-install/keeper/script/startkeeper.sh file not found\"
   fi
   sleep 60
  done
  " > /etc/.keepermonitor.sh;
  chmod 777 /etc/.keepermonitor.sh

  system_dir="/usr/lib/systemd/system";
  serviceName=zcloud_keeper_service.service
  echo "
  [Unit]
  Description=zcloud-keeper is used for custom of zcloud-keeper
  After=network.target network-online.target
  Wants=network-online.target

  [Service]
  Type=simple
  Environment=LANG=en_US.utf8
  ExecStart=/bin/bash -c 'sh /etc/.keepermonitor.sh>>/var/log/zcloud_keepermonitor.log 2>&1'
  Restart=always
  RestartSec=10
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
  " > $system_dir/$serviceName;
  chmod 775 $system_dir/$serviceName
  systemctl daemon-reload
  systemctl restart $serviceName
  systemctl enable $serviceName
  info "安装成功"
  else
    info "此次为标准安装升级，无需执行此步骤"
  fi
}


__InstallKeeperMonitor