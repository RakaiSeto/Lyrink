package model

type PairMessage struct {
	Type string `json:"type"`
	Code string `json:"code"`
}

type DataRequest struct {
	Title          string   `json:"title,omitempty"`
	Artist         string   `json:"artist,omitempty"`
	Album          string   `json:"album,omitempty"`
	AlbumArtBase64 string   `json:"albumArtBase64,omitempty"`
	Timestamp      int64    `json:"timestamp,omitempty"`
	Position       int      `json:"position,omitempty"`
	Duration       int      `json:"duration,omitempty"`
	IsPlaying      bool     `json:"isPlaying,omitempty"`
	State          string   `json:"state,omitempty"`
	PairingCodes   []string `json:"pairingCodes,omitempty"`
}

type DataResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload,omitempty"`
}
