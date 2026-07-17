package handler

import (
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func HandlePost(hub *Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		log.Printf("DEPRECATED: POST /api/data called; use WebSocket instead")

		body, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "failed to read body",
			})
			return
		}

		hub.broadcast <- body

		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": "forwarded to clients",
		})
	}
}
