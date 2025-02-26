package envinit

import "fmt"

var shellFileList = []string{"authLicence.sh", "configSysParam.sh", "createDir.sh", "creatUser.sh", "installDependence.sh"}

func ExecEnvInitShell() {
	for _, file := range shellFileList {
		//todo exec file
		fmt.Print(file)
	}
}
