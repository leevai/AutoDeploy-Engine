package utils

import (
	"AutoDeploy-Engine/config"
	"fmt"
	"io/ioutil"
	"os/exec"
	"strings"
)

func ExecuteShellCommandUseBash(service *config.ServiceConfig, execScript string, isFile bool) (string, error) {

	// ??????????????????????????????????????????????????????????
	if !service.Local {
		// ??????????????????????????????
		stdout, _, err := RemoteSSH(service, fmt.Sprintf("if [ ! -d %s ]; then echo \"dir_not_found\"; fi", service.Name))
		if err != nil {
			return stdout, fmt.Errorf("failed to check remote service directory for %s: %v", service.Name, err)
		}
		if strings.Contains(stdout, "dir_not_found") {
			// ??????????????????????
			if err := RemoteSCP(service, fmt.Sprintf("./services/%s", service.Name), service.InstallPath); err != nil {
				return stdout, fmt.Errorf("failed to copy install package for service %s: %v", service.Name, err)
			}
		}
	}
	if isFile {
		err := ReplaceVarsForFile(execScript)
		if err != nil {
			return "", err
		}
	}
	if isFile && strings.HasSuffix(execScript, ".sql") {
		data, err := ioutil.ReadFile(execScript)
		if err != nil {
			return "", fmt.Errorf("read file %s failed.%s", execScript, err.Error())
		}
		err = ExecMysqlSQL(string(data))
		if err != nil {
			return "", err
		}
		return "sql execute success", nil
	}
	// ??????????????????????????????
	stdout, stderr, err := ExecuteShellCommand(service, execScript)
	if err != nil {
		return stdout, fmt.Errorf("failed to execute install script: %v\nstdout: %s\nstderr: %s", err, stdout, stderr)
	}

	// ????????????????????
	return stdout, nil
}

// executeShellCommand ????Shell????????????????????????????
// ????stdout??stderr????error
func ExecuteShellCommand(service *config.ServiceConfig, cmdstr string) (stdout, stderr string, err error) {
	if service.Local {
		// ????????
		return executeShellLocal(cmdstr)
	} else {
		// ????????
		return RemoteSSH(service, cmdstr)
	}

}

func executeShellLocal(cmdstr string) (stdout, stderr string, err error) {
	var cmd *exec.Cmd
	cmdstr = AddScriptExecutorForLocal(cmdstr)
	cmd = exec.Command("bash", "-c", cmdstr)

	// ??????????????????
	out, err := cmd.CombinedOutput()

	// ??????????????????????????
	stdout = string(out)
	if err != nil {
		stderr = stdout
		// ????????0????????????
		if exitError, ok := err.(*exec.ExitError); ok {
			return stdout, stderr, fmt.Errorf("command failed with exit code %d: %s", exitError.ExitCode(), stderr)
		}
		return stdout, stderr, fmt.Errorf("failed to execute command: %v\nOutput: %s", err, stdout)
	}

	return stdout, stderr, nil
}

func AddScriptExecutorForLocal(cmdstr string) string {
	// ????????
	if strings.HasSuffix(cmdstr, "sh") {
		cmdstr = fmt.Sprintf("%s", cmdstr)
	} else if strings.HasSuffix(cmdstr, "py") {
		cmdstr = fmt.Sprintf("python %s", cmdstr)
	} else if strings.HasSuffix(cmdstr, "url") {
		cmdstr = fmt.Sprintf("%s", cmdstr)
	} else if strings.HasSuffix(cmdstr, "sql") {
		cmdstr = fmt.Sprintf("execute %s", cmdstr)
	} else {
		cmdstr = fmt.Sprintf("%s", cmdstr)
	}
	return cmdstr
}
