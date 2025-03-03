package checker

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"sync"
)

// 安装通用环境检查
func EnvPreCheck(service *config.ServiceConfig) error {
	errCh := make(chan error, len(service.PreCheckScripts))
	var wg sync.WaitGroup
	for _, script := range service.PreCheckScripts {
		wg.Add(1)
		go func(script string) {
			defer wg.Done()
			_, stdErr, err := utils.ExecuteShellCommand(service, script)
			if err != nil {
				errCh <- fmt.Errorf("env pre check failed: %s. %v", stdErr, err)
			}
		}(script)
	}
	wg.Wait()
	var err error
	for scriptErr := range errCh {
		err = scriptErr
	}
	return err
}
