package handler

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"

	"lyrink/model"
)

func HandlePost(hub *Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		body, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusInternalServerError, model.DataResponse{
				Status:  "error",
				Message: "failed to read body",
			})
			return
		}

		var req model.DataRequest
		if err := json.Unmarshal(body, &req); err != nil {
			c.JSON(http.StatusBadRequest, model.DataResponse{
				Status:  "error",
				Message: "invalid JSON",
			})
			return
		}

		if len(req.PairingCodes) == 0 {
			c.JSON(http.StatusBadRequest, model.DataResponse{
				Status:  "error",
				Message: "pairingCodes is required",
			})
			return
		}

		hub.RouteToCodes(req.PairingCodes, body)

		c.JSON(http.StatusOK, model.DataResponse{
			Status:  "ok",
			Message: "forwarded to clients",
		})
	}
}
