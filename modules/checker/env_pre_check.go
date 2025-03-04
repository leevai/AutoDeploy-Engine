package checker

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"sync"
)

// 安装通用环境检查
func EnvPreCheck(service *config.ServiceConfig) error {
	var resErr error
	var wg sync.WaitGroup
	if service.EnvInitScripts == nil || len(service.EnvInitScripts) == 0 {
		return nil
	}
	for _, script := range service.PreCheckScripts {
		wg.Add(1)
		go func(script string) {
			defer wg.Done()
			fmt.Printf("exec env PreCheck script:%s\n", script)
			_, err := utils.ExecuteShellCommandUseBash(service, script, true)
			if err != nil {
				fmt.Printf("exec env PreCheck script:%s, err:%s\n", script, err)
				resErr = err
			}
		}(script)
	}
	wg.Wait()
	return resErr
}
