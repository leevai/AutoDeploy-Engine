package checker

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"database/sql"
	"fmt"
	_ "github.com/go-sql-driver/mysql"
	"io/ioutil"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func CheckConsulStatus(consulAddr string) bool {
	return urlCheckStatus("Consul", fmt.Sprintf("http://%s/v1/status/leader", consulAddr))
}

func CheckEurekaStatus(eurekaAddr string) bool {
	return urlCheckStatus("Eureka", fmt.Sprintf("http://%s/eureka/apps", eurekaAddr))
}

func CheckNginxStatus(nginxAddr string) bool {
	return urlCheckStatus("Nginx", fmt.Sprintf("http://%s", nginxAddr))
}

func urlCheckStatus(app string, url string) bool {
	// 创建一个自定义的 HTTP 客户端，设置超时时间
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	// 向 Consul 的状态 API 端点发送 GET 请求
	resp, err := client.Get(url)
	if err != nil {
		// 处理请求过程中出现的错误
		fmt.Printf("请求 %s 状态时出错: %v\n", app, err)
		return false
	}
	// 确保在函数返回时关闭响应体
	defer resp.Body.Close()

	// 检查响应的状态码
	if resp.StatusCode == http.StatusOK {
		fmt.Printf("%s 已经启动\n", app)
		return true
	}

	// 如果状态码不是 200，说明 Consul 可能未启动或出现异常
	fmt.Printf("%s 未启动或返回异常状态码: %d\n", app, resp.StatusCode)
	return false
}

func CheckPrometheusStatus(prometheusAddr string) bool {
	// 创建一个带有超时设置的 HTTP 客户端
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	// 构建查询表达式的 URL，使用 up 指标来检查
	queryURL := fmt.Sprintf("http://%s/api/v1/query?query=up", prometheusAddr)

	// 发送 HTTP GET 请求
	resp, err := client.Get(queryURL)
	if err != nil {
		fmt.Printf("请求 Prometheus 时出错: %w\n", err)
		return false
	}
	// 确保在函数结束时关闭响应体
	defer resp.Body.Close()

	// 检查响应状态码
	if resp.StatusCode != http.StatusOK {
		body, _ := ioutil.ReadAll(resp.Body)
		fmt.Printf("Prometheus 返回异常状态码 %d，响应内容: %s\n", resp.StatusCode, string(body))
		return false
	}

	// 读取响应体
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("读取 Prometheus 响应体时出错: %w\n", err)
		return false
	}

	// 简单判断，如果响应中包含 "resultType" 和 "result" 字段，认为 Prometheus 可正常服务
	responseStr := string(body)

	if strings.Contains(responseStr, "resultType") && strings.Contains(responseStr, "result") {
		return true
	}
	fmt.Printf("Prometheus 响应不符合预期，响应内容: %s\n", responseStr)
	return false
}

func CheckMySQLStatus(user, password, host, port string) bool {
	// 构建数据库连接字符串
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/mysql", user, password, host, port)

	// 打开数据库连接
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		fmt.Printf("无法打开数据库连接: %w", err)
		return false
	}
	// 确保在函数结束时关闭数据库连接
	defer db.Close()

	// 尝试 ping 数据库，验证连接是否正常
	err = db.Ping()
	if err != nil {
		fmt.Printf("无法连接到数据库: %w", err)
		return false
	}

	// 执行 SELECT 1 语句
	var result int
	err = db.QueryRow("SELECT 1").Scan(&result)
	if err != nil {
		fmt.Printf("执行 SELECT 1 语句时出错: %w", err)
		return false
	}

	return true
}

func CheckKeeperStatus(service *config.ServiceConfig, path string) bool {
	shell := fmt.Sprintf("ps -ef | grep %s/ | grep -v grep | wc -l", path)
	stdout, err := utils.ExecuteShellCommandUseBash(service, shell, false)
	if err != nil {
		fmt.Printf("failed to getKeeper service thread %s: %v\n", service.Name, err)
		return false
	}
	stdout = strings.TrimSpace(stdout)
	keeperThreadNum, err := strconv.Atoi(stdout)
	if err != nil {
		fmt.Printf("failed Atoi %s\n", stdout)
		return false
	}
	return keeperThreadNum > 0
}
