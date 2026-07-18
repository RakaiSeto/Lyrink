package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 524288 // 512KB — temp: album art base64 can exceed 64KB; migrate art to HTTP later
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type wsMessage struct {
	Type     string `json:"type"`
	DeviceId string `json:"deviceId,omitempty"`
}

func HandleWebSocket(hub *Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			log.Printf("websocket upgrade error: %v", err)
			return
		}

		client := &Client{
			conn: conn,
			send: make(chan []byte, 256),
			done: make(chan struct{}),
		}

		hub.register <- client

		go client.writePump()
		go client.readPump(hub)
	}
}

func (c *Client) readPump(hub *Hub) {
	defer func() {
		close(c.done)
		hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	// First message must be a pair message
	_, raw, err := c.conn.ReadMessage()
	if err != nil {
		log.Printf("pair message read error: %v", err)
		return
	}

	var pairMsg struct {
		Type       string `json:"type"`
		Code       string `json:"code"`
		DeviceId   string `json:"deviceId"`
		ClientType string `json:"clientType"`
	}
	if err := json.Unmarshal(raw, &pairMsg); err != nil {
		log.Printf("pair message parse error: %v", err)
		return
	}
	if pairMsg.Type != "pair" || pairMsg.Code == "" {
		log.Printf("invalid pair message: type=%q code=%q", pairMsg.Type, pairMsg.Code)
		return
	}

	c.code = pairMsg.Code
	c.deviceId = pairMsg.DeviceId
	c.clientType = pairMsg.ClientType

	// Subsequent messages
	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			break
		}

		var msg wsMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			log.Printf("message parse error: %v", err)
			continue
		}

		switch msg.Type {
		case "data":
			hub.RouteData(c.code, raw)
		case "control":
			hub.RouteControl(msg.DeviceId, raw)
		default:
			log.Printf("unknown message type: %s", msg.Type)
		}
	}
}
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case <-c.done:
			return
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)
			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
