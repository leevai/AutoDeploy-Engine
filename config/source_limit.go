package config

import (
	"fmt"
	"gopkg.in/yaml.v3"
	"io/ioutil"
	"os"
)

var SourceLimitYamlConfig *Config

type Config struct {
	SourceLimit SourceLimit `yaml:"sourceLimit"`
	Log         Log         `yaml:"log"`
}

type SourceLimit struct {
	CPUUsagePercentage    float64 `yaml:"cpuUsagePercentage"`
	MemoryUsagePercentage float64 `yaml:"memoryUsagePercentage"`
	FreeDiskSpace         float64 `yaml:"freeDiskSpace"`
	MemoryMinimumValue    float64 `yaml:"memoryMinimumValue"`
	DataStoragePath       string  `yaml:"dataStoragePath"`
}

type Log struct {
	Level string `yaml:"level"`
}

// 检查配置参数的有效性
func checkCollectorYamlConfig(config *Config) {
	if config == nil {
		fmt.Println("CollectorYamlConfig is nil")
		os.Exit(1)
	}

	// 检查内存使用率范围
	if config.SourceLimit.MemoryUsagePercentage < 1 || config.SourceLimit.MemoryUsagePercentage > 85 {
		fmt.Println("内存使用率阈值设置，最低百分之 1，最高百分之 85")
		os.Exit(1)
	}

	// 检查 CPU 使用率范围
	if config.SourceLimit.CPUUsagePercentage < 1 || config.SourceLimit.CPUUsagePercentage > 85 {
		fmt.Println("CPU 使用率阈值设置，最低百分之 1，最高百分之 85")
		os.Exit(1)
	}

	// 检查系统总内存可以使用范围
	if config.SourceLimit.MemoryMinimumValue < 3 || config.SourceLimit.MemoryMinimumValue > 2000 {
		fmt.Println("系统内存总大小最低值设置：阈值范围为 3GB 至 2000GB")
		os.Exit(1)
	}

	// 检查磁盘剩余空间范围
	if config.SourceLimit.FreeDiskSpace < 2 || config.SourceLimit.FreeDiskSpace > 20 {
		fmt.Println("硬盘剩余空间最低值设置：阈值范围为 2GB 至 20GB")
		os.Exit(1)
	}

	// 检查日志级别是否合法
	validLogLevels := []string{"debug", "info", "warn", "error"}
	if !SliceExistElem(validLogLevels, config.Log.Level) {
		fmt.Println("日志级别设置错误，可用级别：debug info warn error")
		os.Exit(1)
	}
}

func SliceExistElem(elems []string, elem string) bool {
	for _, item := range elems {
		if item == elem {
			return true
		}
	}
	return false
}

func LoadConfig(path string) (*Config, error) {
	config := &Config{}

	// ????????????
	yamlFile, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}

	// ???? YAML ????
	err = yaml.Unmarshal(yamlFile, config)
	if err != nil {
		return nil, err
	}

	return config, nil
}

func init() {
	var err error
	SourceLimitYamlConfig, err = LoadConfig("./config/source_limit.yaml")
	if err != nil {
		errMsg := fmt.Sprintf("failed to load source limit config: %v", err)
		panic(errMsg)
	}
	checkCollectorYamlConfig(SourceLimitYamlConfig)
}
