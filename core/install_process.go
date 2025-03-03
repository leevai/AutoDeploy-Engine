package core

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/modules/checker"
	"AutoDeploy-Engine/modules/deploy"
	"AutoDeploy-Engine/modules/envinit"
	"fmt"
)

func Install() error {
	fmt.Println("全局变量加载")
	if err := config.LoadGlobalEnvVars(); err != nil {
		return fmt.Errorf("env vars load failed: %v", err)
	}

	fmt.Println("环境初始化")
	if err := envinit.ExecEnvInitShell(); err != nil {
		return fmt.Errorf("env init failed: %v", err)
	}

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
