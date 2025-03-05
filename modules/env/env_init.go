package env

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
)

func ExecEnvInitShell() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			service = item
			break
		}
	}
	var resErr error
	//var wg sync.WaitGroup
	if service.EnvInitScripts == nil || len(service.EnvInitScripts) == 0 {
		return nil
	}
	for _, script := range service.EnvInitScripts {
		//wg.Add(1)
		//go func(script string) {
		//	defer wg.Done()
		fmt.Printf("exec env init script:%s\n", script)
		_, err := utils.ExecuteShellCommandUseBash(service, script, true)
		if err != nil {
			fmt.Printf("exec env init script:%s, err : %s\n", script, err)
			resErr = err
		}
		//}(script)
	}
	//wg.Wait()
	return resErr
}
