package utils

import (
	"AutoDeploy-Engine/config"
	"fmt"
	"io"
	"runtime"
	"strings"
)

// ProcessIDWriter 自定义 Writer，用于在每行输出前添加进程 ID
type ProcessIDWriter struct {
	taskName string
	writer   io.Writer
	buffer   []byte
}

// NewProcessIDWriter 创建一个新的 ProcessIDWriter
func NewProcessIDWriter(service *config.ServiceConfig, writer io.Writer) *ProcessIDWriter {
	return &ProcessIDWriter{
		taskName: service.Name + ":" + service.ServiceName,
		writer:   writer,
	}
}

// Write 实现 io.Writer 接口
func (p *ProcessIDWriter) Write(data []byte) (n int, err error) {
	p.buffer = append(p.buffer, data...)
	lines := strings.Split(string(p.buffer), "\n")
	for i, line := range lines {
		if i < len(lines)-1 {
			// 除了最后一行，其他行都添加进程 ID 并写入
			_, err := p.writer.Write([]byte(fmt.Sprintf("[%s] %s\n", p.taskName, line)))
			if err != nil {
				return 0, err
			}
		}
	}
	// 保存最后一行，可能是不完整的行
	p.buffer = []byte(lines[len(lines)-1])
	return len(data), nil
}

func goId() string {
	buf := make([]byte, 32)
	n := runtime.Stack(buf, false)
	id := strings.Fields(string(buf[:n]))[0]
	return id
}
