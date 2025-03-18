package utils

import (
	"AutoDeploy-Engine/config"
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

func ReplaceVars(content string) string {
	for key, value := range config.GlobalConfigMap {
		switch val := value.(type) {
		case int64:
			content = strings.ReplaceAll(content, fmt.Sprintf(`#{%s}`, key), fmt.Sprintf(`%d`, val))
		case float64:
			content = strings.ReplaceAll(content, fmt.Sprintf(`#{%s}`, key), fmt.Sprintf(`%f`, val))
		default:
			content = strings.ReplaceAll(content, fmt.Sprintf(`#{%s}`, key), fmt.Sprintf(`'%v'`, val))
		}
	}
	return content
}

func ReplaceVarsForFile(serviceName, filename string) (string, error) {
	//data, err := ioutil.ReadFile(filename)
	//if err != nil {
	//	return "", fmt.Errorf("read file %s failed.%s", filename, err.Error())
	//}
	var newFilename string
	if serviceName != "" {
		newFilename = fmt.Sprintf("%s_%s", filename, serviceName) + filepath.Ext(filename)
	} else {
		newFilename = filename + filepath.Ext(filename)
	}
	err := convertFile(filename, newFilename)
	if err != nil {
		return "", fmt.Errorf("convert file %s failed.%s", filename, err.Error())
	}
	//newContent := ReplaceVars(string(data))
	//newContent = fmt.Sprintf("%s", newContent)
	//
	//err = ioutil.WriteFile(newFilename, []byte(newContent), fs.ModePerm)
	//if err != nil {
	//	return "", fmt.Errorf("write file %s failed.%s", filename, err.Error())
	//}
	return newFilename, nil
}

func convertFile(inputPath, outputPath string) error {
	// 打开输入文件
	inputFile, err := os.Open(inputPath)
	if err != nil {
		return fmt.Errorf("无法打开输入文件: %w", err)
	}
	defer inputFile.Close()

	// 创建输出文件
	outputFile, err := os.OpenFile(outputPath, os.O_RDWR|os.O_CREATE|os.O_TRUNC, fs.ModePerm)
	if err != nil {
		return fmt.Errorf("无法创建输出文件: %w", err)
	}
	defer outputFile.Close()

	scanner := bufio.NewScanner(inputFile)
	writer := bufio.NewWriter(outputFile)

	// 逐行读取输入文件
	for scanner.Scan() {
		line := scanner.Text()
		line = ReplaceVars(line)
		// 移除行末的 \r 字符
		line = strings.TrimRight(line, "\r")
		// 写入输出文件
		_, err := writer.WriteString(line + "\n")
		if err != nil {
			return fmt.Errorf("写入输出文件时出错: %w", err)
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("读取输入文件时出错: %w", err)
	}

	// 刷新缓冲区
	return writer.Flush()
}
