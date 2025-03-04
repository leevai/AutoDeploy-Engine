package utils

import (
	"AutoDeploy-Engine/config"
	"bytes"
	"context"
	"fmt"
	"io/ioutil"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func ExecuteShellCommandUseBash(service *config.ServiceConfig, execScript string, isFile bool) (string, error) {
	var err error
	newExecScript := execScript
	if isFile {
		newExecScript, err = ReplaceVarsForFile(execScript)
		if err != nil {
			return "", err
		}
	}

	if !service.Local {
		stdout, _, err := RemoteSSH(service, fmt.Sprintf("if [ ! -d %s ]; then echo \"dir_not_found\"; fi", filepath.Join(service.InstallPath, service.Name)))
		if err != nil {
			return stdout, fmt.Errorf("failed to check remote service directory for %s: %v", service.Name, err)
		}
		if strings.Contains(stdout, "dir_not_found") {
			stdout, _, err := RemoteSSH(service, fmt.Sprintf("mkdir -p %s", service.InstallPath))
			if err != nil {
				return stdout, fmt.Errorf("failed to mkdir remote service directory for %s: %v", service.InstallPath, err)
			}
			if err := RemoteSCP(service, fmt.Sprintf("./services/%s", service.Name), filepath.Join(service.InstallPath, service.Name)); err != nil {
				return stdout, fmt.Errorf("failed to copy install package for service %s: %v", service.Name, err)
			}
		} else {
			if err := RemoteSCP(service, newExecScript, filepath.Join(service.InstallPath, service.Name)); err != nil {
				return stdout, fmt.Errorf("failed to copy install package for service %s: %v", service.Name, err)
			}
		}
	}

	if isFile && strings.HasSuffix(newExecScript, ".sql") {
		data, err := ioutil.ReadFile(newExecScript)
		if err != nil {
			return "", fmt.Errorf("read file %s failed.%s", newExecScript, err.Error())
		}
		err = ExecMysqlSQL(string(data))
		if err != nil {
			return "", err
		}
		return "sql execute success", nil
	}
	if !service.Local {
		newExecScript = filepath.Join(service.InstallPath, service.Name, filepath.Base(newExecScript))
	}
	stdout, stderr, err := ExecuteShellCommand(service, newExecScript)
	if err != nil {
		return stdout, fmt.Errorf("failed to execute install script: %v\nstdout: %s\nstderr: %s", err, stdout, stderr)
	}
	return stdout, nil
}

func ExecuteShellCommand(service *config.ServiceConfig, cmdstr string) (stdout, stderr string, err error) {
	if service.Local {
		return executeShellLocal(cmdstr)
	} else {
		return RemoteSSH(service, cmdstr)
	}

}

func executeShellLocal(cmdstr string) (stdout, stderr string, err error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3000*time.Second) // 设置超时
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", "-c", cmdstr) // 明确使用 bash
	var outBuf, errBuf bytes.Buffer
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf

	if err := cmd.Start(); err != nil {
		return "", "", fmt.Errorf("启动命令失败: %v", err)
	}

	// 等待命令完成（父进程退出即可）
	err = cmd.Wait()
	stdout = outBuf.String()
	stderr = errBuf.String()

	if ctx.Err() == context.DeadlineExceeded {
		return stdout, stderr, fmt.Errorf("执行超时")
	}
	return stdout, stderr, err
}

func AddScriptExecutorForLocal(cmdstr string) string {
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
