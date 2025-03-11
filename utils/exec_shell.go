package utils

import (
	"AutoDeploy-Engine/config"
	"bytes"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
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

	if !service.Local && isFile {
		stdout, _, err := RemoteSSH(service, fmt.Sprintf("if [ ! -d %s ]; then echo \"dir_not_found\"; fi", "./zcloud"))
		if err != nil {
			return stdout, fmt.Errorf("failed to check remote service directory for %s: %v", "./zcloud", err)
		}
		if strings.Contains(stdout, "dir_not_found") {
			stdout, _, err := RemoteSSH(service, fmt.Sprintf("mkdir -p %s", "./zcloud"))
			if err != nil {
				return stdout, fmt.Errorf("failed to mkdir remote service directory for %s: %v", "./zcloud", err)
			}
		}
		if err := RemoteSCP(service, newExecScript, "~/zcloud"); err != nil {
			return stdout, fmt.Errorf("failed to copy install package for service %s: %v", service.Name, err)
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
		newExecScript = filepath.Join("./zcloud", filepath.Base(newExecScript))
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
	//cmd.Stdout = &outBuf
	//cmd.Stderr = &errBuf

	// 获取命令的标准输出管道
	stdoutP, err := cmd.StdoutPipe()
	if err != nil {
		// 若获取标准输出管道出错，打印错误信息
		log.Fatalf("获取标准输出管道出错: %v", err)
	}
	// 获取命令的标准错误输出管道
	stderrP, err := cmd.StderrPipe()
	if err != nil {
		// 若获取标准错误输出管道出错，打印错误信息
		log.Fatalf("获取标准错误输出管道出错: %v", err)
	}

	// 启动命令执行
	if err := cmd.Start(); err != nil {
		// 若启动命令出错，打印错误信息
		log.Fatalf("启动命令出错: %v", err)
	}
	mwOut := io.MultiWriter(os.Stdout, &outBuf)
	mwErr := io.MultiWriter(os.Stderr, &errBuf)

	// 将标准输出复制到 os.Stdout，实时显示输出
	go io.Copy(mwOut, stdoutP)
	// 将标准错误输出复制到 os.Stderr，实时显示错误输出
	go io.Copy(mwErr, stderrP)

	// 等待命令执行完成
	if err := cmd.Wait(); err != nil {
		// 若命令执行过程中出错，打印错误信息
		log.Fatalf("命令执行出错: %v", err)
	}

	// 等待命令完成（父进程退出即可）
	//err = cmd.Wait()
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
