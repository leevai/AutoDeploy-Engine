package checker

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/utils"
	"fmt"
	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/disk"
	"github.com/shirou/gopsutil/mem"
	"os"
	"strconv"
	"strings"
	"time"
)

func CronCheckSourceLimit() {
	CheckAndHandLeResources(config.SourceLimitYamlConfig.SourceLimit)
	go func() {
		time.Sleep(5 * time.Second)
		CheckAndHandLeResources(config.SourceLimitYamlConfig.SourceLimit)
	}()
}

// ????????????CPU???????????? interval ?? 1 ????????
func getAveCpuUsage() (float64, error) {
	avgUsage, err := cpu.Percent(time.Second, false) // false ????????????
	if err != nil {
		fmt.Println(fmt.Sprintf("Error retrieving average CPU usage: %v", err))
		os.Exit(1)
	}
	fmt.Println(fmt.Sprintf("Average CPU Usage: %.2f%%\n", avgUsage[0]))
	return avgUsage[0], nil
}

// ????????????????????0.0 ~ 100.0??????????????
func getMemoryUsage() (float64, error) {
	vmStat, err := mem.VirtualMemory()
	if err != nil {
		return 0, fmt.Errorf("failed to get memory info: %v", err)
	}
	// ????????????????
	fmt.Println(fmt.Sprintf("Average Mem Usage: %.2f%%\n", vmStat.UsedPercent))
	return vmStat.UsedPercent, nil
}

// 参数：path 指定的文件路径
// 返回：剩余空间大小(GB)，可能的错误
func getPathFreeSpace(path string) (float64, error) {
	// 获取指定路径的磁盘使用情况
	diskStat, err := disk.Usage(path)
	if err != nil {
		return 0, fmt.Errorf("failed to get disk usage for path %s: %v", path, err)
	}
	diskStatFree := float64(diskStat.Free) / (1024 * 1024 * 1024)
	diskStatFree = float64(int(diskStatFree*100)) / 100
	fmt.Printf("硬盘剩余空间: %.2fGB\n", diskStatFree)
	// 返回剩余空间大小
	return diskStatFree, nil
}

// ????????????????????0.0 ~ 100.0??????????????
func getMemoryUsageByShell(service *config.ServiceConfig) (float64, error) {
	stdout, err := utils.ExecuteShellCommandUseBash(service, "free | grep Mem | awk '{print $3/$2 * 100.0}'", false)
	if err != nil {
		return 0, fmt.Errorf("failed to getMemoryUsageByShell service %s: %v", service.Name, err)
	}
	stdout = strings.TrimSpace(stdout)
	memUsage, err := strconv.ParseFloat(stdout, 64)
	if err != nil {
		return 0, err
	}
	return memUsage, nil
}

// ????????????CPU???????????? interval ?? 1 ????????
func getAveCpuUsageByShell(service *config.ServiceConfig) (float64, error) {
	stdout, err := utils.ExecuteShellCommandUseBash(service, "top -bn1 | grep \"Cpu(s)\" | sed \"s/.*, *\\([0-9.]*\\)%* id.*/\\1/\" | awk '{print 100 - $1}'", false)
	if err != nil {
		return 0, fmt.Errorf("failed to getAveCpuUsageByShell service %s: %v", service.Name, err)
	}
	stdout = strings.TrimSpace(stdout)
	cpuUsage, err := strconv.ParseFloat(stdout, 64)
	if err != nil {
		return 0, err
	}
	return cpuUsage, nil
}

func getPathFreeSpaceByShell(service *config.ServiceConfig, path string) (float64, error) {
	stdout, err := utils.ExecuteShellCommandUseBash(service, fmt.Sprintf("df -BG %s | awk 'NR==2 {print $4}'", path), false)
	if err != nil {
		return 0, fmt.Errorf("failed to getPathFreeSpaceByShell service %s: %v", service.Name, err)
	}
	stdout = strings.TrimSpace(stdout)
	stdout = strings.TrimRight(strings.ToLower(stdout), "g")
	freeSpaceGB, err := strconv.ParseFloat(stdout, 64)
	if err != nil {
		return 0, err
	}
	return freeSpaceGB, nil
}

func getOsTotalMemoryByShell(service *config.ServiceConfig) (float64, error) {
	stdout, err := utils.ExecuteShellCommandUseBash(service, "free -g | grep Mem | awk '{print $2}'", false)
	if err != nil {
		return 0, fmt.Errorf("failed to getOsTotalMemoryByShell service %s: %v", service.Name, err)
	}
	stdout = strings.TrimSpace(stdout)
	totalMemGB, err := strconv.ParseFloat(stdout, 64)
	if err != nil {
		return 0, err
	}
	return totalMemGB, nil
}

// CheckAndHandLeResources 记录日志并根据阈值判断是否停止进程
func CheckAndHandLeResources(conf config.SourceLimit) {
	zcloudService := config.GetZcloudService()
	// 当前系统CPU占用比大小
	sysAveCpuUsage, err := getAveCpuUsageByShell(zcloudService)
	if err != nil {
		fmt.Printf("Failed to get CPU load: %v\n", err)
		os.Exit(1)
	}

	// 当前系统内存占用比大小
	memUsagePercentage, err := getMemoryUsageByShell(zcloudService)
	if err != nil {
		fmt.Printf("Failed to get memory usage: %v\n", err)
		os.Exit(1)
	}

	// 磁盘剩余空间
	diskSpace, err := getPathFreeSpaceByShell(zcloudService, conf.DataStoragePath)
	if err != nil {
		fmt.Printf("Failed to get disk space: %v\n", err)
		os.Exit(1)
	}

	totalMemGB, err := getOsTotalMemoryByShell(zcloudService)
	if err != nil {
		fmt.Printf("Failed to get disk space: %v\n", err)
		os.Exit(1)
	}

	// 检查操作系统总内存是否低于阈值
	if totalMemGB < conf.MemoryMinimumValue {
		fmt.Printf("当前系统 总内存 是 %.2fGB, 应用配置阈值是不低于 %.2fGB 采集器终止运行\n", totalMemGB, conf.MemoryMinimumValue)
		os.Exit(1)
	}

	// 检查CPU负载是否超过阈值
	if sysAveCpuUsage > conf.CPUUsagePercentage {
		fmt.Printf("当前系统 CPU 占比是 %.2f%%, 应用配置阈值CPU占用为 %.2f%%. 采集器终止运行\n", sysAveCpuUsage, conf.CPUUsagePercentage)
		os.Exit(1)
	}

	// 检查内存使用率是否超过阈值
	if memUsagePercentage > conf.MemoryUsagePercentage {
		fmt.Printf("当前系统内存占比是 %.2f%%, 应用配置阈值内存占用为 %.2f%%. 采集器终止运行\n", memUsagePercentage, conf.MemoryUsagePercentage)
		os.Exit(1)
	}

	// 检查磁盘剩余空间是否低于阈值
	if diskSpace < conf.FreeDiskSpace {
		fmt.Printf("当前系统磁盘剩余空间是 %.2fGB, 应用配置阈值磁盘剩余空间最低为 %.2fGB. 采集器终止运行\n", diskSpace, conf.FreeDiskSpace)
		os.Exit(1)
	}
}
