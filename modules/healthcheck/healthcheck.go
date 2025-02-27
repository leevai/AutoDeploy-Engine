package healthcheck

import (
	"AutoDeploy-Engine/modules/checker"
	"fmt"
)

func HealthCheck() {
	//var service *config.ServiceConfig
	//for _, item := range config.MicroServices {
	//	if item.Name == "zcloud" {
	//		service = item
	//		break
	//	}
	//}

	var consulAddr string
	if !checker.CheckConsulStatus(consulAddr) {
		fmt.Printf("Consul 状态检查失败")
	}

	//todo
	var eurekaAddr string
	if !checker.CheckEurekaStatus(eurekaAddr) {
		fmt.Printf("Eureka 状态检查失败")
	}

	//todo
	var nginxAddr string
	if !checker.CheckNginxStatus(nginxAddr) {
		fmt.Printf("Nginx 状态检查失败")
	}

	//todo
	var prometheusAddr string
	if !checker.CheckPrometheusStatus(prometheusAddr) {
		fmt.Printf("Prometheus 状态检查失败")
	}

	//todo
	var user, pwd, ip, port string
	if !checker.CheckMySQLStatus(user, pwd, ip, port) {
		fmt.Printf("MySQL 状态检查失败")
	}
}
