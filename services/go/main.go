package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host, _ := os.Hostname()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"lang": "go", "color": "#00ADD8", "host": host,
		})
	})
	log.Println("go hue listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
