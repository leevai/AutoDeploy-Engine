#!/bin/bash

#Licence赋权
startTime=$(date +"%s%N")
if [[ ${installType} != 4 ]];then
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
  info "licence赋权成功"
else
  info "此次为标准安装升级，无需执行此步骤"
fi
endTime=$(date +"%s%N")
info "Licence赋权完成，耗时$( __CalcDuration ${startTime} ${endTime})"