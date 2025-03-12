package core

import (
	"AutoDeploy-Engine/modules/deploy"
	"fmt"
)

func Upgrade() error {
	if err := deploy.Upgrade(); err != nil {
		return fmt.Errorf("upgrade failed: %v", err)
	}

	fmt.Println("Upgrade completed successfully!")
	return nil
}
