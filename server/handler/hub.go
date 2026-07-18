package handler

import (
	"encoding/json"
	"log"

	"github.com/gorilla/websocket"
)

type Client struct {
	conn       *websocket.Conn
	send       chan []byte
	done       chan struct{}
	code       string
	deviceId   string
	clientType string
}

type Hub struct {
	clients    map[*Client]bool
	data       chan dataMessage
	control    chan []byte
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
}

type dataMessage struct {
	senderCode string
	body       []byte
}
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		data:       make(chan dataMessage, 256),
		control:    make(chan []byte, 256),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
			log.Printf("ws client connected (code=%q deviceId=%q), total: %d",
				client.code, client.deviceId, len(h.clients))
			h.broadcastPhoneStatus(client.code)

		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			} 
			log.Printf("ws client disconnected (code=%q deviceId=%q), total: %d",
				client.code, client.deviceId, len(h.clients))
			h.broadcastPhoneStatus(client.code)

		case dm := <-h.data:
			if dm.senderCode == "" {
				log.Printf("hub: data message from unpaired client, ignoring")
				continue
			}
			for client := range h.clients {
				if client.code == dm.senderCode && client != nil {
				select {
				case client.send <- dm.body:
				default:
					log.Printf("hub: send buffer full, dropping data for code=%q", client.code)
				}
				}
			}

		case message := <-h.control:
			var msg struct {
				DeviceId string `json:"deviceId"`
			}
			if err := json.Unmarshal(message, &msg); err != nil {
				log.Printf("hub: failed to parse deviceId: %v", err)
				continue
			}
			for client := range h.clients {
				if client.deviceId == msg.DeviceId {
				select {
				case client.send <- message:
				default:
					log.Printf("hub: send buffer full, dropping control for deviceId=%q", msg.DeviceId)
				}
					break
				}
			}
			log.Printf("ws client disconnected, total: %d", len(h.clients))

		case dm := <-h.data:
			if dm.senderCode == "" {
				log.Printf("hub: data message from unpaired client, ignoring")
				continue
			}
			for client := range h.clients {
				if client.code == dm.senderCode && client != nil {
				select {
				case client.send <- dm.body:
				default:
					log.Printf("hub: send buffer full, dropping data for code=%q", client.code)
				}
				}
			}

		case message := <-h.control:
			var msg struct {
				DeviceId string `json:"deviceId"`
			}
			if err := json.Unmarshal(message, &msg); err != nil {
				log.Printf("hub: failed to parse deviceId: %v", err)
				continue
			}
			for client := range h.clients {
				if client.deviceId == msg.DeviceId {
				select {
				case client.send <- message:
				default:
					log.Printf("hub: send buffer full, dropping control for deviceId=%q", msg.DeviceId)
				}
					break
				}
			}

		case message := <-h.broadcast:
			for client := range h.clients {
			select {
			case client.send <- message:
			default:
				log.Printf("hub: send buffer full, dropping broadcast message")
			}
			}
		}
	}
}

func (h *Hub) RouteData(senderCode string, body []byte) {
	h.data <- dataMessage{senderCode: senderCode, body: body}
}

func (h *Hub) RouteControl(deviceId string, body []byte) {
	h.control <- body
}

func (h *Hub) broadcastPhoneStatus(code string) {
	phoneConnected := false
	for client := range h.clients {
		if client.code == code && client.clientType == "phone" {
			phoneConnected = true
			break
		}
	}
	msg, err := json.Marshal(map[string]interface{}{
		"type":           "status",
		"phoneConnected": phoneConnected,
	})
	if err != nil {
		log.Printf("hub: failed to marshal phone status: %v", err)
		return
	}
	for client := range h.clients {
		if client.code == code && client.clientType == "widget" {
			select {
			case client.send <- msg:
			default:
				log.Printf("hub: send buffer full, dropping phone status for widget code=%q", code)
			}
		}
	}
}
