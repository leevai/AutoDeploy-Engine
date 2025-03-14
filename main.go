package main

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/core"
	"AutoDeploy-Engine/modules/checker"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: install-deploy <install|upgrade|uninstall|backup|rollback|change-ip>")
		return
	}
	checker.CronCheckSourceLimit()

	action := os.Args[1]
	switch action {
	case "install":
		config.InsertToGlobalVars("installType", 1)
		if err := core.Install(); err != nil {
			fmt.Println("Install failed:", err)
			return
		}
		//fmt.Println("Installation completed successfully!")

	case "upgrade":
		config.InsertToGlobalVars("installType", 4)
		if err := core.Upgrade(); err != nil {
			fmt.Println("Upgrade failed:", err)
			return
		}
	case "Unload":
		if err := core.Unload(); err != nil {
			fmt.Println("Upgrade failed:", err)
			return
		}
	//	//fmt.Println("Upgrade completed successfully!")
	//
	//case "uninstall":
	//	if err := deploy.Uninstall(); err != nil {
	//		fmt.Println("Uninstall failed:", err)
	//		return
	//	}
	//	fmt.Println("Uninstall completed successfully!")
	//
	//case "backup":
	//	if err := deploy.Backup(); err != nil {
	//		fmt.Println("Backup failed:", err)
	//		return
	//	}
	//	fmt.Println("Backup completed successfully!")
	//
	//case "rollback":
	//	if err := deploy.Rollback(); err != nil {
	//		fmt.Println("Rollback failed:", err)
	//		return
	//	}
	//	fmt.Println("Rollback completed successfully!")
	//
	//case "change-ip":
	//	if err := deploy.ChangeIP(); err != nil {
	//		fmt.Println("Change IP failed:", err)
	//		return
	//	}
	//	fmt.Println("IP Address changed successfully!")

	default:
		fmt.Println("Invalid command. Usage: install-deploy <install|upgrade|uninstall|backup|rollback|change-ip|start|stop|status>")
	}
}
