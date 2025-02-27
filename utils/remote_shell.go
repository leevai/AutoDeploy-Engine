package utils

import (
	"AutoDeploy-Engine/config"
	"fmt"
	"golang.org/x/crypto/ssh"
	"os/exec"
	"strings"
	"time"
)

// ????????????????????????
func CopyPackageToRemote(service *config.ServiceConfig) error {
	// ???? scp ????
	scpCmd := fmt.Sprintf("scp %s %s@%s:%s", service.UpgradePackage, service.Remote.User, service.Remote.Host, service.InstallPath)
	cmd := exec.Command("bash", "-c", scpCmd)

	// ???? scp ????
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to copy package to remote server: %v, output: %s", err, output)
	}

	return nil
}

// RemoteSCP ????????????????????????????
func RemoteSCP(service *config.ServiceConfig, localFile string, remoteFile string) error {
	// ???? service ????????????????????
	host := service.Remote.Host
	user := service.Remote.User
	password := service.Remote.Password

	// ???????????????????? sshpass ?????????????? scp ????
	cmdStr := fmt.Sprintf("sshpass -p %s scp -o StrictHostKeyChecking=no -r %s %s@%s:%s", password, localFile, user, host, remoteFile)

	// ????????
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to copy file to remote server: %v\nOutput: %s", err, string(output))
	}

	return nil
}

// ???? SSH ????????????
func RemoteSSH(service *config.ServiceConfig, cmdstr string) (stdout, stderr string, err error) {
	// ????????????
	clientConfig := &ssh.ClientConfig{
		User: service.Remote.User,
		Auth: []ssh.AuthMethod{
			ssh.Password(service.Remote.Password),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // ????????????????
		Timeout:         5 * time.Second,
	}

	// ???? SSH ????
	conn, err := ssh.Dial("tcp", fmt.Sprintf("%s:%d", service.Remote.Host, service.Remote.Port), clientConfig)
	if err != nil {
		err = fmt.Errorf("failed to connect to remote server: %v", err)
		return
	}
	defer conn.Close()

	// ??????????????
	session, err := conn.NewSession()
	if err != nil {
		err = fmt.Errorf("failed to create session: %v", err)
		return
	}
	defer session.Close()

	cmdstr = AddScriptExecutorForRemote(cmdstr)
	output, err := session.CombinedOutput(cmdstr) // ??????????????
	if err != nil {
		err = fmt.Errorf("failed to execute command on remote server: %v, output: %s", err, output)
		return
	}
	stdout = string(output)

	return

}

func AddScriptExecutorForRemote(cmdstr string) string {
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
