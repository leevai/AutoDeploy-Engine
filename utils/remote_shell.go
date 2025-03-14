package utils

import (
	"AutoDeploy-Engine/config"
	"bytes"
	"fmt"
	"golang.org/x/crypto/ssh"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"
)

func CopyPackageToRemote(service *config.ServiceConfig) error {
	// ???? scp ????
	scpCmd := fmt.Sprintf("scp %s %s@%s:%s", service.UpgradePackage, service.Remote.User, service.Remote.Host, service.InstallPath)
	cmd := exec.Command("bash", "-c", scpCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to copy package to remote server: %v, output: %s", err, output)
	}

	return nil
}

func RemoteSCP(service *config.ServiceConfig, localFile string, remoteFile string) error {
	host := service.Remote.Host
	user := service.Remote.User
	cmdStr := fmt.Sprintf("scp -o StrictHostKeyChecking=no -r %s %s@%s:%s", localFile, user, host, remoteFile)
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to copy file to remote server: %v\nOutput: %s", err, string(output))
	}

	return nil
}

func SCPToLocal(service *config.ServiceConfig, localFile string, remoteFile string) error {
	host := service.Remote.Host
	user := service.Remote.User
	cmdStr := fmt.Sprintf("scp -o StrictHostKeyChecking=no -r %s@%s:%s %s", user, host, remoteFile, localFile)
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to copy file to remote server: %v\nOutput: %s", err, string(output))
	}

	return nil
}

func RemoteSSH(service *config.ServiceConfig, cmdstr string) (string, string, error) {
	clientConfig := &ssh.ClientConfig{
		User: service.Remote.User,
		Auth: []ssh.AuthMethod{
			ssh.Password(service.Remote.Password),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         5 * time.Second,
	}

	conn, err := ssh.Dial("tcp", fmt.Sprintf("%s:%d", service.Remote.Host, service.Remote.Port), clientConfig)
	if err != nil {
		err = fmt.Errorf("failed to connect to remote server: %v", err)
		return "", "", err
	}
	defer conn.Close()
	session, err := conn.NewSession()
	if err != nil {
		err = fmt.Errorf("failed to create session: %v", err)
		return "", "", err
	}
	defer session.Close()

	args := ""
	if service.ServiceName != "" {
		args = service.ServiceName
	}
	cmdstr = AddScriptExecutorForRemote(cmdstr, args)
	if strings.Contains(cmdstr, ".sh") {
		var outBuf, errBuf bytes.Buffer
		// 获取命令的标准输出管道
		stdoutP, err2 := session.StdoutPipe()
		if err2 != nil {
			// 若获取标准输出管道出错，打印错误信息
			log.Fatalf("获取标准输出管道出错: %v", err)
			return "", "", err2
		}
		// 获取命令的标准错误输出管道
		stderrP, err := session.StderrPipe()
		if err != nil {
			// 若获取标准错误输出管道出错，打印错误信息
			log.Fatalf("获取标准错误输出管道出错: %v", err)
			return "", "", err
		}

		// 启动命令执行
		if err := session.Start(cmdstr); err != nil {
			// 若启动命令出错，打印错误信息
			log.Fatalf("启动命令出错: %v", err)
			return "", "", err
		}

		mwOut := io.MultiWriter(os.Stdout, &outBuf)
		mwErr := io.MultiWriter(os.Stderr, &errBuf)
		// 将标准输出复制到 os.Stdout，实时显示输出
		go io.Copy(mwOut, stdoutP)
		// 将标准错误输出复制到 os.Stderr，实时显示错误输出
		go io.Copy(mwErr, stderrP)
		// 等待命令执行完成
		if err := session.Wait(); err != nil {
			// 若命令执行过程中出错，打印错误信息
			log.Fatalf("命令执行出错: %v", err)
			return "", "", err
		}

		stdout := outBuf.String()
		stderr := errBuf.String()
		return stdout, stderr, nil
	} else {
		output, err := session.CombinedOutput(cmdstr)
		if err != nil {
			err = fmt.Errorf("failed to execute command on remote server: %v, output: %s", err, output)
			return "", "", err
		}

		return string(output), "", err
	}
}

func AddScriptExecutorForRemote(cmdstr string, args string) string {
	if strings.HasSuffix(cmdstr, "sh") {
		cmdstr = fmt.Sprintf("bash -c \"export TERM=xterm; cd ./zcloud; %s %s\"", cmdstr, args)
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
