installType=#{installType}

#Licence赋权
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
  echo "licence赋权成功"
else
  echo "此次为标准安装升级，无需执行此步骤"
fi
