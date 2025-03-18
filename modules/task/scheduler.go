package task

import (
	"AutoDeploy-Engine/config"
	"AutoDeploy-Engine/modules/checker"
	"fmt"
	"sync"
	"time"
)

type nodeScheduler struct {
	nodeName      string
	goroutineNum  int
	taskPriority2 chan func() error
	taskPriority3 chan func() error
}

var nodeTaskMap = make(map[string]*nodeScheduler)

func init() {
	for _, nodeConfig := range config.Nodes {
		nodeS := &nodeScheduler{
			nodeName:      nodeConfig.Name,
			taskPriority2: make(chan func() error, 10),
			taskPriority3: make(chan func() error, 50),
		}

		//todo 计算节点goroutine数
		//nodeS.goroutineNum = 2
		nodeS.goroutineNum = 2
		nodeTaskMap[nodeConfig.Name] = nodeS
	}
}

func AddTask(service *config.ServiceConfig, task func() error) {
	var taskNode *nodeScheduler
	if service.Local {
		taskNode = nodeTaskMap["local"]
	} else {
		taskNode = nodeTaskMap[service.RemoteName]
	}

	if service.Priority == 2 {
		taskNode.taskPriority2 <- task
	} else {
		taskNode.taskPriority3 <- task
	}
}

func RunTask() {
	errChan := make(chan error)
	p2HealthCheckSuccess := false
	var mu sync.Mutex
	cond := sync.NewCond(&mu)
	wg := sync.WaitGroup{}

	for _, taskNode := range nodeTaskMap {
		close(taskNode.taskPriority2)
		for {
			task, ok := <-taskNode.taskPriority2
			if ok {
				err := task()
				if err != nil {
					errChan <- err
				}
			} else {
				break
			}
		}

	}

	for _, taskNode := range nodeTaskMap {
		//关闭通道
		close(taskNode.taskPriority3)
		for i := 1; i <= taskNode.goroutineNum; i++ {
			wg.Add(1)
			go func(taskNode *nodeScheduler) {
				defer wg.Done()
				for {
					task, ok := <-taskNode.taskPriority2
					if ok {
						err := task()
						if err != nil {
							errChan <- err
						}
					}

					mu.Lock()
					//健康检查未通过且p2任务已执行完；挂起
					for !p2HealthCheckSuccess && !ok {
						cond.Wait()
					}
					mu.Unlock()

					//p2任务全部执行完毕
					if !ok {
						task2, ok2 := <-taskNode.taskPriority3
						if !ok2 {
							//所有任务已执行完
							break
						}
						err := task2()
						if err != nil {
							errChan <- err
						}
					}
				}
			}(taskNode)
		}
	}

	for {
		time.Sleep(5 * time.Second)
		if healthCheck() {
			//健康检查通过
			//等一下flyway
			time.Sleep(180 * time.Second)
			mu.Lock()
			p2HealthCheckSuccess = true
			mu.Unlock()
			//唤醒所有goroutine
			cond.Broadcast()
			break
		}
	}
	wg.Wait()
}

func healthCheck() bool {
	if ok := checker.CheckConsulStatus(fmt.Sprintf("%v:%d", config.GlobalConfigMap["consulHost"], 8500)); !ok {
		return false
	}
	if ok := checker.CheckEurekaStatus(fmt.Sprintf("%v:%d", config.GlobalConfigMap["webIp"], 8761)); !ok {
		return false
	}
	if ok := checker.CheckNginxStatus(fmt.Sprintf("%v:%d", config.GlobalConfigMap["webIp"], 8080)); !ok {
		return false
	}
	if ok := checker.CheckPrometheusStatus(fmt.Sprintf("%v:%d", config.GlobalConfigMap["prometheusIp"], 8093)); !ok {
		return false
	}

	//if "MySQL" == fmt.Sprintf("%v", config.GlobalConfigMap["databaseType"]) {
	//	if ok := checker.CheckMySQLStatus(); !ok {
	//		return false
	//	}
	//} else {
	//	if ok := checker.CheckMogDBStatus(); !ok {
	//		return false
	//	}
	//}
	return true
}
