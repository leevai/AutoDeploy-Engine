package backup

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
)

func ExecuteBackUp() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "backup" {
			service = item
			break
		}
	}
	var resErr error
	//var wg sync.WaitGroup
	if service.EnvInitScripts == nil || len(service.EnvInitScripts) == 0 {
		return nil
	}
	logPathInterface := config.GetGlobalVars("bakPath")
	bakPath, _ := logPathInterface.(string)
	installPathInterface := config.GetGlobalVars("installPath")
	installPath, _ := installPathInterface.(string)
	databaseTypeInterface := config.GetGlobalVars("databaseType")
	databaseType, _ := databaseTypeInterface.(string)
	// 读取日志文件
	command := "./script/backup/backup.sh " + installPath + " " + bakPath + " " + databaseType
	_, err := utils.ExecuteShellCommandUseBash(service, command, true)
	if err != nil {
		return fmt.Errorf("failed to backup %s: %v", service.Name, err)
	}
	return resErr
}

func ExecuteRestore() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "backup" {
			service = item
			break
		}
	}
	var resErr error
	//var wg sync.WaitGroup
	if service.EnvInitScripts == nil || len(service.EnvInitScripts) == 0 {
		return nil
	}
	logPathInterface := config.GetGlobalVars("bakPath")
	bakPath, _ := logPathInterface.(string)
	installPathInterface := config.GetGlobalVars("installPath")
	installPath, _ := installPathInterface.(string)
	databaseTypeInterface := config.GetGlobalVars("databaseType")
	databaseType, _ := databaseTypeInterface.(string)
	// 读取日志文件
	command := "./script/backup/restore.sh " + installPath + " " + bakPath + " " + databaseType
	_, err := utils.ExecuteShellCommandUseBash(service, command, true)
	if err != nil {
		return fmt.Errorf("failed to backup %s: %v", service.Name, err)
	}
	return resErr
}
