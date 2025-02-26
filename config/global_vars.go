package config

import (
	"fmt"
	"gopkg.in/yaml.v3"
	"io/ioutil"
	"sync"
)

var GlobalConfigMap = make(map[string]interface{})
var globalVarsLock sync.Mutex
var loadErr error

type golbalVarsConfig struct {
	ConfigMap map[string]interface{} `yaml:",inline"`
}

func LoadGlobalVarsConfig(path string) {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		loadErr = fmt.Errorf("failed to read config file: %v", err)
		return
	}

	var configMap golbalVarsConfig
	err = yaml.Unmarshal(data, &configMap)
	if err != nil {
		loadErr = fmt.Errorf("failed to parse YAML: %v", err)
		return
	}

	globalVars := configMap.ConfigMap["global_vars"]
	for key, value := range globalVars.(map[string]interface{}) {
		GlobalConfigMap[fmt.Sprintf("%v", key)] = value
	}
}

func init() {
	LoadGlobalVarsConfig("./config/global_vars.yaml")
}

func InsertToGlobalVars(key string, value interface{}) {
	globalVarsLock.Lock()
	defer globalVarsLock.Unlock()
	GlobalConfigMap[key] = value
}
