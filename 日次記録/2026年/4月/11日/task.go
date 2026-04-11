package main

import (
	"fmt"
	"time"
)

func task1(ch chan string) {
	time.Sleep(1 * time.Second)
	ch <- "task1 done"
}

func task2(ch chan string) {
	time.Sleep(2 * time.Second)
	ch <- "task2 done"
}

func task3(ch chan string) {
	time.Sleep(3 * time.Second)
	ch <- "task3 done"
}

func main() {
	ch := make(chan string)

	go task1(ch)
	go task2(ch)
	go task3(ch)

	result1 := <-ch
	result2 := <-ch
	result3 := <-ch

	fmt.Println(result1, result2, result3)
}
