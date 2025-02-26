package utils

import (
	"AutoDeploy-Engine/config"
	"fmt"
	"io/fs"
	"io/ioutil"
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

func ReplaceVarsForFile(filename string) error {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return fmt.Errorf("read file %s failed.%s", filename, err.Error())
	}
	netContent := ReplaceVars(string(data))
	err = ioutil.WriteFile(filename, []byte(netContent), fs.ModePerm)
	if err != nil {
		return fmt.Errorf("write file %s failed.%s", filename, err.Error())
	}
	return nil
}
