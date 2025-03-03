package config

import (
	"AutoDeploy-Engine/utils"
	"fmt"
	"os/user"
	"strings"
)

func LoadGlobalEnvVars() error {
	var config *ServiceConfig
	for _, item := range MicroServices {
		if item.Name == "zcloud" {
			config = item
			break
		}
	}
	if err := getPath(config); err != nil {
		return fmt.Errorf("path env vars load failed: %v", err)
	}
	if err := getInstallType(config); err != nil {
		return fmt.Errorf("install type env vars load failed: %v", err)
	}
	if err := getOsTypeVer(config); err != nil {
		return fmt.Errorf("os type env vars load failed: %v", err)
	}
	if err := getExecUser(); err != nil {
		return fmt.Errorf("exec user env vars load failed: %v", err)
	}
	return nil
}

func getPath(config *ServiceConfig) error {
	var theme = fmt.Sprintf("theme=%s\n", config.Theme)
	var shell = "executeUser=`whoami`\n" +
		"if [[ ${theme} == \"zData\" ]];then\n  " +
		"homePath=\"/opt/db_manager_standard\"\n" +
		"elif [[ ${executeUser} != \"root\" ]];then\n  " +
		"homePath=$(cd ~ &&pwd)\n" +
		"else\n  " +
		"homePath=$(su - zcloud -c \"cd ~ &&pwd\")\n" +
		"fi\n" +
		"echo \"${homePath}\""
	homePath, stderr, err := utils.ExecuteShellCommand(config, theme+shell)
	if err != nil {
		fmt.Println(stderr)
		return err
	}

	InsertToGlobalVars("homePath", homePath)
	InsertToGlobalVars("installPath", fmt.Sprintf("%s/dbaas/soft-install", homePath))
	InsertToGlobalVars("logPath", fmt.Sprintf("%s/dbaas/zcloud-log", homePath))
	InsertToGlobalVars("logFile", fmt.Sprintf("%s/dbaas/zcloud-log/install.log", homePath))
	InsertToGlobalVars("packagePath", fmt.Sprintf("%s/dbaas/soft-package", homePath))
	InsertToGlobalVars("bakPath", fmt.Sprintf("%s/dbaas/soft-bak", homePath))
	InsertToGlobalVars("configPath", fmt.Sprintf("%s/dbaas/zcloud-config", homePath))
	InsertToGlobalVars("javaIoTempDir", fmt.Sprintf("%s/dbaas/zcloud-log/java-io-tmpdir", homePath))

	workdirCmd := "cd \"$( dirname \"${BASH_SOURCE[0]}\" )\" && pwd"
	workdir, stderr, err := utils.ExecuteShellCommand(config, workdirCmd)
	if err != nil {
		fmt.Println(stderr)
		return err
	}
	InsertToGlobalVars("workdir", workdir)
	return nil
}

func getInstallType(config *ServiceConfig) error {
	installType, err := utils.ExecuteShellCommandUseBash(config, "./script/env_vars/install_type.sh", true)
	if err != nil {
		return err
	}
	InsertToGlobalVars("installType", installType)
	return nil
}

func getOsTypeVer(config *ServiceConfig) error {
	osTypeVer, err := utils.ExecuteShellCommandUseBash(config, "./script/env_vars/os_type.sh", true)
	if err != nil {
		return err
	}
	varVal := strings.Split(osTypeVer, ";")
	if len(varVal) != 2 {
		return fmt.Errorf("getOsTypeVer data err: %s", osTypeVer)
	}
	InsertToGlobalVars("osType", varVal[0])
	InsertToGlobalVars("osVersion", varVal[1])
	return nil
}

func getExecUser() error {
	currentUser, err := user.Current()
	if err != nil {
		return fmt.Errorf("获取当前用户信息时出错: %v\n", err)
	}
	InsertToGlobalVars("executeUser", currentUser.Username)
	return nil
}
