package core

import (
	"AutoDeploy-Engine/modules/deploy"
	"AutoDeploy-Engine/modules/env"
	"fmt"
)

func Upgrade() error {
	fmt.Println("全局变量加载")
	if err := env.LoadGlobalEnvVars(); err != nil {
		return fmt.Errorf("env vars load failed: %v", err)
	}
	if err := deploy.Upgrade(); err != nil {
		return fmt.Errorf("upgrade failed: %v", err)
	}

	fmt.Println("Upgrade completed successfully!")
	return nil
}
