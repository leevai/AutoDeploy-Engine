package flyway

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"regexp"
	"strings"
)

func CheckErrorFlyway() error {
	var service *config.ServiceConfig
	for _, item := range config.MicroServices {
		if item.ServiceName == "dbaas-flyway-manage" {
			service = item
			break
		}
	}
	var resErr error
	//var wg sync.WaitGroup
	if service.EnvInitScripts == nil || len(service.EnvInitScripts) == 0 {
		return nil
	}
	logPathInterface := config.GetGlobalVars("logPath")
	logPath, _ := logPathInterface.(string)
	// 读取日志文件
	command := "FILE_PATH=\"/" + logPath + "\"  \n\n# 判断文件是否存在  \nif [ ! -f \"$FILE_PATH\" ]; then  \n    echo \"错误：文件 $FILE_PATH 不存在\" >&2  \n    exit 1  # 返回非零错误码  \nfi  \n\n# 读取最后500条数据（按行）  \ntail -n 500 \"$FILE_PATH\"  \nexit 0"
	result, err := utils.ExecuteShellCommandUseBash(service, command, false)
	if err != nil {
		return fmt.Errorf("failed to getMemoryUsageByShell service %s: %v", service.Name, err)
	}
	dealError(result)
	return resErr
}

func dealError(result string) {
	re := regexp.MustCompile(`\r?\n`) // 匹配 \n 或 \r\n
	lines := re.Split(result, -1)
	var version string
	var dbChecksum string
	var fileChecksum string
	var schemaTable string
	for i := 0; i < len(lines); i++ { // 使用 for i 循环
		line := strings.TrimSpace(lines[i])
		//flyway 报错
		if strings.Contains(line, "[ERROR]") && strings.Contains(lines[i+1], "org.flywaydb.core.api.FlywayException") {
			i++
			re := regexp.MustCompile(` `)
			splitList := re.Split(lines[i], -1)
			version = strings.TrimSpace(splitList[len(splitList)-1])
			re = regexp.MustCompile(`name\s*'([^']+)'`)
			matches := re.FindStringSubmatch(lines[i])
			if len(matches) > 1 {
				beanName := matches[1]
				schemaTable = QuerySchemaTable(beanName, config.GetGlobalVars("databaseType").(string))
			}
			databaseType := config.GetGlobalVars("databaseType").(string)
			if strings.Contains(lines[i], "Migration checksum mismatch for migration") {
				re = regexp.MustCompile(`:`)
				if i < len(lines) {
					line = strings.TrimSpace(lines[i+1])
					splitList = re.Split(line, -1)
					dbChecksum = strings.TrimSpace(splitList[len(splitList)-1])
				}
				if i+1 < len(lines) {
					line = strings.TrimSpace(lines[i+2])
					splitList = re.Split(line, -1)
					fileChecksum = strings.TrimSpace(splitList[len(splitList)-1])
				}
				i += 2
				// 更新checksum
				if databaseType == "MySQL" {
					sql := "update" + schemaTable + " set checksum = '" + fileChecksum + "' where `version` = '" + version + "'"
					_ = utils.ExecMysqlSQL(sql)
				} else {
					sql := "update" + schemaTable + " set checksum = '" + fileChecksum + "' where \"version\" = '" + version + "'"
					_ = utils.ExecMogDBSQL(sql)
				}
				fmt.Println("flyway error ,file changed , version is "+version+",db checksum is ", dbChecksum, ",file checksum is ", fileChecksum)

			} else if strings.Contains(line, "Detected applied migration not resolved locally") {
				// 删除flyway记录
				if databaseType == "MySQL" {
					sql := "delete from " + schemaTable + " where `version` = '" + version + "'"
					_ = utils.ExecMysqlSQL(sql)
				} else {
					sql := "delete from " + schemaTable + " where \"version\" = '" + version + "'"
					_ = utils.ExecMogDBSQL(sql)
				}
				fmt.Println("flyway is delete , version is " + version)
			} else if strings.Contains(line, "contains a failed migration to version") {
				// 记录错误日志
				fmt.Println("flyway sql error , version is " + version)
			}

		}
	}
}

func QuerySchemaTable(beanName string, dbType string) string {
	if dbType == "MySQL" && beanName == "flyway" {
		return "dbaas.dbaas_flyway_schema_history"
	} else if dbType == "MogDB" && beanName == "flyway" {
		return "dbaas.mogdb_dbaas_flyway_schema_history"
	} else if dbType == "MySQL" && beanName == "monitorFlyway" {
		return "monitormanager.monitormanager_flyway_schema_history"
	} else if dbType == "MogDB" && beanName == "monitorFlyway" {
		return "monitormanager.mogdb_monitormanager_flyway_schema_history"
	} else if dbType == "MySQL" && beanName == "activityDatasourceFlyway" {
		return "activiti.activiti_flyway_schema_history"
	} else if dbType == "MogDB" && beanName == "activityDatasourceFlyway" {
		return "activiti.mogdb_activiti_flyway_schema_history"
	} else if dbType == "MySQL" && beanName == "snapshotFlyway" {
		return "`database-snapshot`.snapshot_flyway_schema_history"
	} else if dbType == "MogDB" && beanName == "snapshotFlyway" {
		return "\"database-snapshot\".mogdb_snapshot_flyway_schema_history"
	} else if dbType == "MySQL" && beanName == "lowcodeworkflowFlyway" {
		return "lowcodeworkflow.lowcodeworkflow_flyway_schema_history"
	} else if dbType == "MogDB" && beanName == "lowcodeworkflowFlyway" {
		return "lowcodeworkflow.mogdb_lowcodeworkflow_flyway_schema_history"
	} else if dbType == "MySQL" && beanName == "zdbmonFlyway" {
		return "zdbmon_config.zdbmon_flyway_schema_history"
	} else if dbType == "MogDB" && beanName == "zdbmonFlyway" {
		return "zdbmon_config.mogdb_zdbmon_flyway_schema_history"
	} else if dbType == "MySQL" && beanName == "series" {
		return "series.series_flyway_schema_history"
	} else {
		return "series.mogdb_series_flyway_schema_history"
	}
}

func main() {
	a := "[2025-03-11 16:07:27] [main] [ERROR] [org.springframework.boot.SpringApplication:870] Application run failed\norg.springframework.beans.factory.BeanCreationException: Error creating bean with name 'flyway' defined in class path resource [com/enmo/flyway/config/MogdbFlywayAutoConfiguration.class]: Invocation of init method failed; nested exception is org.flywaydb.core.api.FlywayException: Validate failed: Migration checksum mismatch for migration 24.10.28.1040810.0\n-> Applied to database : -2056389094\n-> Resolved locally    : -2056389093"
	dealError(a)
}
