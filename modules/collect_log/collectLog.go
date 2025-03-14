package collect_log

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"time"
)

func CollectLog() error {
	var services []*config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			services = append(services, item)
			break
		}
	}
	var resErr error
	for _, service := range services {
		homePath := config.GetGlobalVars("logPath").(string)
		// 获取当前时间
		now := time.Now()
		dateNow := now.Format("20060102150405")
		command := "cd " + homePath + "/dbaas; tar -zcvf zcloud-log." + dateNow + ".tar.gz zcloud-log"
		_, errOut, resErr := utils.RemoteSSH(service, command)
		if resErr != nil {
			return fmt.Errorf(errOut, resErr)
		}

		resErr = utils.SCPToLocal(service, homePath+"/dbaas/zcloud-log."+dateNow+".tar.gz", "./")
		if resErr != nil {
			return fmt.Errorf("scp error,"+resErr.Error(), resErr)
		}
	}
	//var wg sync.WaitGroup
	return resErr
}
