package handler

import (
	"log"

	"github.com/gorilla/websocket"
)

type Client struct {
	conn *websocket.Conn
	send chan []byte
	code string
}

type Hub struct {
	clients    map[*Client]bool
	register   chan *Client
	unregister chan *Client
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
			log.Printf("ws client connected, total: %d", len(h.clients))

		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			log.Printf("ws client disconnected, total: %d", len(h.clients))
		}
	}
}

func (h *Hub) RouteToCodes(codes []string, data []byte) {
	codeSet := make(map[string]bool, len(codes))
	for _, c := range codes {
		codeSet[c] = true
	}

	for client := range h.clients {
		if client.code == "" {
			continue
		}
		if !codeSet[client.code] {
			continue
		}
		select {
		case client.send <- data:
		default:
			close(client.send)
			delete(h.clients, client)
		}
	}
}
