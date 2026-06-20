package main

import (
	"github.com/gin-gonic/gin"

	"lyrink/handler"
)

func main() {
	hub := handler.NewHub()
	go hub.Run()

	r := gin.Default()

	r.POST("/api/data", handler.HandlePost(hub))
	r.GET("/ws", handler.HandleWebSocket(hub))

	r.Run(":8080")
}
