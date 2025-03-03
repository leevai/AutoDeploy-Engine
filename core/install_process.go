package core

import (
	"AutoDeploy-Engine/modules/checker"
	"AutoDeploy-Engine/modules/deploy"
	"fmt"
)

func Install() error {
	fmt.Println("前置检查")
	if err := checker.PerformPreDeploymentChecks(); err != nil {
		return fmt.Errorf("preinstall check failed: %v", err)
	}

	//fmt.Println("Backing up configurations...")
	//err := backup.BackupService("MySQL")
	//if err != nil {
	//	return fmt.Errorf("backup failed: %v", err)
	//}

	//fmt.Println("starting backup...")
	//if err := deploy.Backup(); err != nil {
	//	return fmt.Errorf("backup failed: %v", err)
	//}
	//fmt.Println("backup completed successfully!")
	//fmt.Println("Starting installation...")
	if err := deploy.Install(); err != nil {
		return fmt.Errorf("installation failed: %v", err)
	}

	fmt.Println("Installation completed successfully!")
	return nil
}
