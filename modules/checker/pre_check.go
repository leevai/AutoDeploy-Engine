package checker

import (
	"AutoDeploy-Engine/config"
	"fmt"
)

func PerformPreDeploymentChecks() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			service = item
			break
		}
	}

	err := EnvPreCheck(service)
	if err != nil {
		fmt.Println("pre check failed", err)
		return err
	}
	fmt.Println("Environment checks completed successfully.")
	return nil
}
