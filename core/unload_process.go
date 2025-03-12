package core

import (
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

	fmt.Println("Upgrade completed successfully!")
	return nil
}
