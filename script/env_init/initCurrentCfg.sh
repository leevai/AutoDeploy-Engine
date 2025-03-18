installNodeType=#{installNodeType}
nodeNum=#{nodeNum}

#配置参数
if [[ ${installNodeType} == "OneNode" ]]; then
    cp nodeconfig/single.cfg nodeconfig/current.cfg
else
    if [[ ${nodeNum} != 1 ]]; then
        acltoken=$( __readINI zcloud.cfg multiple consul.acl.token )
        if [[ ${acltoken} == "" ]] || [[ ${acltoken} == "acltoken" ]] ; then
            echo "当前节点需要配置consul.acl.token"
            exit 1
        fi
    fi
fi
if [[ ${installNodeType} == "TwoNodes" ]]; then
    cp nodeconfig/double.cfg nodeconfig/current.cfg
fi
if [[ ${installNodeType} == "FourNodes" ]]; then
    cp nodeconfig/four.cfg nodeconfig/current.cfg
fi
