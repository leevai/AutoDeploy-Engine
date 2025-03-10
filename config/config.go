package config

import (
	"fmt"
	"gopkg.in/yaml.v3"
	"io/ioutil"
	"sort"
)

type RemoteConfig struct {
	Name     string `yaml:"name"`
	Host     string `yaml:"host"`
	Port     uint16 `yaml:"port"`
	User     string `yaml:"user"`
	Password string `yaml:"password"`
}

type ServiceConfig struct {
	Name              string            `yaml:"name"`
	Local             bool              `yaml:"local"`
	RemoteName        string            `yaml:"remote_name"`
	Remote            *RemoteConfig     `yaml:"remote,omitempty"`
	PreCheckScripts   []string          `yaml:"pre_check_scripts"`
	EnvInitScripts    []string          `yaml:"env_init_scripts"`
	PkgCopyMap        map[string]string `yaml:"pkg_copy_map"`
	InstallPackage    string            `yaml:"install_package"`
	UpgradePackage    string            `yaml:"upgrade_package"`
	InstallScript     string            `yaml:"install_script"`
	UpgradeScript     string            `yaml:"upgrade_script"`
	UninstallScript   string            `yaml:"uninstall_script"`
	RollbackScript    string            `yaml:"rollback_script"`
	CheckHealthScript string            `yaml:"check_health_script"`
	BackupScript      string            `yaml:"backup_script"`
	ChangeIPScript    string            `yaml:"change_ip_script"`
	InstallPath       string            `yaml:"install_path"`
	StartCommand      string            `yaml:"start_command"`
	Priority          int               `yaml:"priority"`
}

func LoadServiceConfig(configFile string) ([]*ServiceConfig, error) {
	data, err := ioutil.ReadFile(configFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %v", err)
	}

	var servicesConfig struct {
		Nodes    []*RemoteConfig  `yaml:"nodes"`
		Services []*ServiceConfig `yaml:"services"`
	}

	if err := yaml.Unmarshal(data, &servicesConfig); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %v", err)
	}

	nodeMap := make(map[string]*RemoteConfig, len(servicesConfig.Nodes))
	for _, remoteConfig := range servicesConfig.Nodes {
		nodeMap[remoteConfig.Name] = remoteConfig
	}

	sort.SliceStable(servicesConfig.Services, func(i, j int) bool {
		return servicesConfig.Services[i].Priority < servicesConfig.Services[j].Priority
	})

	for _, config := range servicesConfig.Services {
		if !config.Local {
			if _, ok := nodeMap[config.RemoteName]; ok {
				config.Remote = nodeMap[config.RemoteName]
			} else {
				return nil, fmt.Errorf("failed to parse node : %s", config.RemoteName)
			}
		}
	}

	//log.Printf("Successfully loaded %d services from config file %s", len(servicesConfig.Services), configFile)
	return servicesConfig.Services, nil
}

var MicroServices []*ServiceConfig

func init() {
	var err error
	MicroServices, err = LoadServiceConfig("config/services.yaml")
	if err != nil {
		errMsg := fmt.Sprintf("failed to load service config: %v", err)
		panic(errMsg)
	}
}

func GetZcloudService() *ServiceConfig {
	for _, item := range MicroServices {
		if item.Name == "zcloud" {
			return item
		}
	}
	return nil
}

func LoadSingleServiceConfig(configFile string) (*ServiceConfig, error) {
	data, err := ioutil.ReadFile(configFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %v", err)
	}

	var servicesConfig struct {
		Service *ServiceConfig `yaml:"service"`
	}

	if err := yaml.Unmarshal(data, &servicesConfig); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %v", err)
	}

	//log.Printf("Successfully loaded %d services from config file %s", len(servicesConfig.Services), configFile)
	return servicesConfig.Service, nil
}

func loadEnvVar(config *ServiceConfig) {

}
