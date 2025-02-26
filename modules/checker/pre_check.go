package checker

import (
	"fmt"
	"sync"
)

var shellFileList = []string{"checkCpuCore.sh", "checkDirExist.sh", "checkDiskCapacity.sh", "checkMemory.sh", "checkTimeZone.sh"}

func ExecPreCheckShell() error {
	var wg sync.WaitGroup
	errCh := make(chan error)
	for _, file := range shellFileList {
		wg.Add(1)
		go func(file string) {
			defer wg.Done()
			//todo exec file
			fmt.Print(file)
			var err error
			if err != nil {
				errCh <- err
			}
		}(file)
	}
	wg.Wait()

	select {
	case err := <-errCh:
		fmt.Print(err)
		return err
		//exit failed
	default:
		fmt.Print("success")
		return nil
	}
}
