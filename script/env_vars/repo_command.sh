if [[ `yum repolist all|grep zcloud|wc -l` > 0 ]]; then
  repoCommand="--disablerepo=zcloud"
fi
echo "repoCommand=${repoCommand}"