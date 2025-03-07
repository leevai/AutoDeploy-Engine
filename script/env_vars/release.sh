workdir=#{workdir}
installPath=#{installPath}

if [[ -f ${workdir}/zcloud_release.txt ]];then
  release=`cat zcloud_release.txt`
else
  release="enterprise"
fi
if [[ -f ${installPath}/zcloud_release.txt ]];then
  oldRelease=`cat ${installPath}/zcloud_release.txt`
else
  oldRelease="enterprise";
fi

echo "release=${release};oldRelease=${oldRelease}"