package env

import (
	config2 "AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"os/user"
	"strings"
)

func LoadGlobalEnvVars() error {
	var config *config2.ServiceConfig
	for _, item := range config2.MicroServices {
		if item.Name == "zcloud" {
			config = item
			break
		}
	}
	stdout, err := utils.ExecuteShellCommandUseBash(config, "chmod a+x -R ./script", false)
	if err != nil {
		return fmt.Errorf("chmod failed msg:%s, err: %v", stdout, err)
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
	if err := getExecUser(config); err != nil {
		return fmt.Errorf("exec user env vars load failed: %v", err)
	}
	if err := execEnvVarsScript(config, "./script/env_vars/repo_command.sh"); err != nil {
		return fmt.Errorf("repoCommand env vars load failed: %v", err)
	}
	if err := execEnvVarsScript(config, "./script/env_vars/release.sh"); err != nil {
		return fmt.Errorf("release env vars load failed: %v", err)
	}
	return nil
}

func getPath(config *config2.ServiceConfig) error {
	homePath, err := utils.ExecuteShellCommandUseBash(config, "./script/env_vars/install_path.sh", true)
	if err != nil {
		return err
	}
	homePath = strings.TrimSpace(homePath)
	fmt.Printf("homePath: %s, ok", homePath)

	config2.InsertToGlobalVars("homePath", homePath)
	config2.InsertToGlobalVars("installPath", fmt.Sprintf("%s/dbaas/soft-install", homePath))
	config2.InsertToGlobalVars("logPath", fmt.Sprintf("%s/dbaas/zcloud-log", homePath))
	config2.InsertToGlobalVars("logFile", fmt.Sprintf("%s/dbaas/zcloud-log/install.log", homePath))
	config2.InsertToGlobalVars("packagePath", fmt.Sprintf("%s/dbaas/soft-package", homePath))
	config2.InsertToGlobalVars("bakPath", fmt.Sprintf("%s/dbaas/soft-bak", homePath))
	config2.InsertToGlobalVars("configPath", fmt.Sprintf("%s/dbaas/zcloud-config", homePath))
	config2.InsertToGlobalVars("javaIoTempDir", fmt.Sprintf("%s/dbaas/zcloud-log/java-io-tmpdir", homePath))
	config2.InsertToGlobalVars("keeperConf", fmt.Sprintf("%s/dbaas/zcloud-config/keeper.yaml", homePath))

	workdirCmd := "cd \"$( dirname \"${BASH_SOURCE[0]}\" )\" && pwd"
	workdir, stderr, err := utils.ExecuteShellCommand(config, workdirCmd)
	if err != nil {
		fmt.Println(stderr)
		return err
	}
	config2.InsertToGlobalVars("workdir", strings.TrimSpace(workdir))
	return nil
}

func getInstallType(config *config2.ServiceConfig) error {
	installType, err := utils.ExecuteShellCommandUseBash(config, "./script/env_vars/install_type.sh", true)
	if err != nil {
		return err
	}
	config2.InsertToGlobalVars("installType", strings.TrimSpace(installType))
	return nil
}

func getOsTypeVer(config *config2.ServiceConfig) error {
	osTypeVer, err := utils.ExecuteShellCommandUseBash(config, "./script/env_vars/os_type.sh", true)
	if err != nil {
		return err
	}
	varVal := strings.Split(osTypeVer, ";")
	if len(varVal) != 2 {
		return fmt.Errorf("getOsTypeVer data err: %s", osTypeVer)
	}
	config2.InsertToGlobalVars("osType", strings.TrimSpace(varVal[0]))
	config2.InsertToGlobalVars("osVersion", strings.TrimSpace(varVal[1]))
	return nil
}

func getExecUser(config *config2.ServiceConfig) error {
	if config.Local {
		currentUser, err := user.Current()
		if err != nil {
			return fmt.Errorf("获取当前用户信息时出错: %v\n", err)
		}
		config2.InsertToGlobalVars("executeUser", currentUser.Username)
	} else {
		config2.InsertToGlobalVars("executeUser", config.Remote.User)
	}
	return nil
}

func execEnvVarsScript(config *config2.ServiceConfig, scriptFile string) error {
	data, err := utils.ExecuteShellCommandUseBash(config, scriptFile, true)
	if err != nil {
		return err
	}
	varValList := strings.Split(data, ";")
	for _, varVal := range varValList {
		kv := strings.SplitN(data, "=", 2)
		if len(kv) != 2 {
			return fmt.Errorf("data err: %s", varVal)
		}
		config2.InsertToGlobalVars(strings.TrimSpace(kv[0]), strings.TrimSpace(kv[1]))
	}
	return nil
}
