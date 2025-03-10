package env

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"strings"
)

func ExecEnvInitShell() error {
	var services []*config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			services = append(services, item)
			break
		}
	}
	var resErr error
	//var wg sync.WaitGroup
	for _, service := range services {
		if service.EnvInitScripts == nil || len(service.EnvInitScripts) == 0 {
			return nil
		}
		for _, script := range service.EnvInitScripts {
			fmt.Printf("exec env init script:%s\n", script)
			_, err := utils.ExecuteShellCommandUseBash(service, script, true)
			if err != nil {
				fmt.Printf("exec env init script:%s, err : %s\n", script, err)
				resErr = err
			}
		}
	}

	return resErr
}

func CopyScriptLibRemote() error {
	var services []*config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			services = append(services, item)
			break
		}
	}
	for _, service := range services {
		if !service.Local {
			stdout, _, err := utils.RemoteSSH(service, fmt.Sprintf("if [ ! -d %s ]; then echo \"dir_not_found\"; fi", "./zcloud/script/"))
			if err != nil {
				return fmt.Errorf("failed to check remote service directory for %s: %v", "zcloud/script/", err)
			}
			if strings.Contains(stdout, "dir_not_found") {
				_, _, err := utils.RemoteSSH(service, fmt.Sprintf("mkdir -p %s", "./zcloud/script/"))
				if err != nil {
					return fmt.Errorf("failed to mkdir remote service directory for %s: %v", "zcloud/script/", err)
				}
			}
			if err := utils.RemoteSCP(service, "./script/lib", "./zcloud/script/"); err != nil {
				return fmt.Errorf("failed to copy install package for service %s: %v", service.Name, err)
			}
		}
	}
	return nil
}
