package task

import (
	"AutoDeploy-Engine/config"
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
		nodeS.goroutineNum = 2
		nodeTaskMap[nodeConfig.Name] = nodeS
	}
}

func AddTask(service *config.ServiceConfig, task func() error) {
	taskNode := nodeTaskMap[service.RemoteName]
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

	for _, taskNode := range nodeTaskMap {
		//关闭通道
		close(taskNode.taskPriority2)
		close(taskNode.taskPriority3)
		for i := 1; i < taskNode.goroutineNum; i++ {
			go func(taskNode *nodeScheduler) {
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
			mu.Lock()
			p2HealthCheckSuccess = true
			mu.Unlock()
			//唤醒所有goroutine
			cond.Broadcast()
			break
		}
	}

}

func healthCheck() bool {
	return true
}
