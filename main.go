package main

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/core"
	"AutoDeploy-Engine/modules/backup"
	"AutoDeploy-Engine/modules/checker"
	"fmt"
	"os"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: install-deploy <install|upgrade|uninstall|backup|rollback|change-ip>")
		return
	}
	checker.CronCheckSourceLimit()

	action := os.Args[1]
	startTime := time.Now()
	switch action {
	case "install":
		config.InsertToGlobalVars("installType", 1)
		if err := core.Install(); err != nil {
			fmt.Println("Install failed:", err)
			return
		}

		endTime := time.Now()
		fmt.Printf("install start at %s end at %s, cost %f min\n", startTime, endTime, endTime.Sub(startTime).Minutes())

	case "upgrade":
		config.InsertToGlobalVars("installType", 4)
		if err := core.Upgrade(); err != nil {
			fmt.Println("Upgrade failed:", err)
			return
		}
	case "uninstall":
		if err := core.Unload(); err != nil {
			fmt.Println("uninstall failed:", err)
			return
		}
	case "backup":
		if err := backup.ExecuteBackUp(); err != nil {
			fmt.Println("Backup failed:", err)
			return
		}
		fmt.Println("Backup completed successfully!")

	case "rollback":
		if err := backup.ExecuteRestore(); err != nil {
			fmt.Println("Rollback failed:", err)
			return
		}
		fmt.Println("Rollback completed successfully!")

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
