package main

import "fmt"

const VERSION = "1.0.0"

type Point struct {
    X float64
    Y float64
}

func add(a, b int) int {
    return a + b
}

func main() {
    fmt.Println("Hello, World!")
}

type Status int

const (
    StatusOK Status = iota
    StatusError
)

var globalConfig = map[string]string{
    "debug": "false",
}