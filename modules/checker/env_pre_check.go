package checker

import (
	"AutoDeploy-Engine/config"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
)

//安装通用环境检查

func EnvPreCheck() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.Name == "zcloud" {
			service = item
			break
		}
	}
	var scripts = strings.Split(service.PreCheckScripts, ",")
	errCh := make(chan error, len(scripts))
	var wg sync.WaitGroup
	for _, script := range scripts {
		wg.Add(1)
		go func() {
			defer wg.Done()
			cmd := exec.Command(script)
			// 设置环境变量
			cmd.Env = append(os.Environ(), "MY_VARIABLE=hello")
			// 执行命令并获取输出结果
			err := cmd.Run()
			if err != nil {
				errCh <- err
			}
		}()
	}
	wg.Wait()
	var err error
	for scriptErr := range errCh {
		err = scriptErr
		fmt.Println(scriptErr)
	}
	return err
}
