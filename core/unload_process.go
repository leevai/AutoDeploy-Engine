package core

import (
	"AutoDeploy-Engine/modules/uninstall"
	"fmt"
	"os/user"
)

func Unload() error {
	currentUser, err := user.Current()
	if err != nil {
		return fmt.Errorf("获取当前用户信息时出错: %v\n", err)
	}
	if currentUser.Username != "root" {
		return fmt.Errorf("执行用户只能为root")
	}
	err = uninstall.UnInstall()
	if err != nil {
		return err
	}
	fmt.Println("uninstall completed successfully!")
	return nil
}
