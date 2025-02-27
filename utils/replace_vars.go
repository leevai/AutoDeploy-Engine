package utils

import (
	"AutoDeploy-Engine/config"
	"fmt"
	"io/fs"
	"io/ioutil"
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

func ReplaceVarsForFile(filename string) (string, error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return "", fmt.Errorf("read file %s failed.%s", filename, err.Error())
	}
	newContent := ReplaceVars(string(data))
	newFilename := filename + filepath.Ext(filename)
	err = ioutil.WriteFile(newFilename, []byte(newContent), fs.ModePerm)
	if err != nil {
		return "", fmt.Errorf("write file %s failed.%s", filename, err.Error())
	}
	return newFilename, nil
}
