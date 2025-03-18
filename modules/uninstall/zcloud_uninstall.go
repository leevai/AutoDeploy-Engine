package uninstall

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
)

func UnInstall() error {
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
	command := "./script/uninstall/zcloud_uninstall.sh"
	_, err := utils.ExecuteShellCommandUseBash(service, command, true)
	if err != nil {
		return fmt.Errorf("failed to uninstall %s: %v", service.Name, err)
	}
	return resErr
}
