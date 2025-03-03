package envinit

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"sync"
)

func ExecEnvInitShell() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			service = item
			break
		}
	}
	errCh := make(chan error, len(service.EnvInitScripts))
	var wg sync.WaitGroup
	for _, script := range service.EnvInitScripts {
		wg.Add(1)
		go func(script string) {
			defer wg.Done()
			_, _, err := utils.ExecuteShellCommand(service, script)
			if err != nil {
				errCh <- err
			}
		}(script)
	}
	wg.Wait()
	var err error
	for scriptErr := range errCh {
		err = scriptErr
		fmt.Println(scriptErr)
	}
	return err
}
