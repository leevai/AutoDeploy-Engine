package deploy

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
)

func Install() error {
	fmt.Println("开始安装")
	for _, service := range config.MicroServices {
		fmt.Printf("Installing service: %s\n", service.Name)
		serviceDetail, err := config.LoadSingleServiceConfig(fmt.Sprintf("./services/%s/service.yaml", service.Name))
		if err != nil {
			return err
		}

		output, err := utils.ExecuteShellCommandUseBash(service, serviceDetail.InstallScript, true)
		if err != nil {
			return fmt.Errorf("failed to install service %s: %v", service.Name, err)
		}
		fmt.Println(output)
	}
	return nil
}
