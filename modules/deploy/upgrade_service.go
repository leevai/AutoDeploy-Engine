package deploy

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"path/filepath"
	"strings"
)

func Upgrade() error {
	fmt.Println("开始升级")
	for _, service := range config.MicroServices {
		fmt.Printf("Upgrade service: %s\n", service.Name)
		serviceDetail, err := config.LoadSingleServiceConfig(fmt.Sprintf("./services/%s/service.yaml", service.Name))
		if err != nil {
			return err
		}

		if service.PkgCopyMap != nil && len(service.PkgCopyMap) != 0 {
			for source, target := range service.PkgCopyMap {
				stdout, _, err := utils.RemoteSSH(service, fmt.Sprintf("if [ ! -d %s ]; then echo \"dir_not_found\"; fi", filepath.Dir(target)))
				if err != nil {
					return fmt.Errorf("failed to check remote service directory for %s: %v", service.Name, err)
				}
				if strings.Contains(stdout, "dir_not_found") {
					_, _, err := utils.RemoteSSH(service, fmt.Sprintf("mkdir -p %s", filepath.Dir(target)))
					if err != nil {
						return fmt.Errorf("failed to mkdir remote service directory for %s: %v", service.InstallPath, err)
					}
				}
				err = utils.RemoteSCP(service, source, target)
				if err != nil {
					return err
				}
			}
		}

		cmdStr := serviceDetail.UpgradeScript
		if service.ServiceName != "" {
			cmdStr = cmdStr + " " + service.ServiceName
		}
		output, err := utils.ExecuteShellCommandUseBash(service, cmdStr, true)
		if err != nil {
			return fmt.Errorf("failed to install service %s: %v", service.Name, err)
		}
		fmt.Println(output)
	}
	return nil
}
