// The player application loads audio blobs and integrates them into a media player
package main

import (
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"runtime"
	"strings"
	"sync"
	"time"

	"perkeep.org/pkg/app"
	"perkeep.org/pkg/auth"
	"perkeep.org/pkg/buildinfo"
	"perkeep.org/pkg/client"
	"perkeep.org/pkg/search"
	"perkeep.org/pkg/webserver"
)

/*
TODO:
  * Elm Player Application
*/

var (
	flagVersion = flag.Bool("version", false, "show version")
)

var (
	logger = log.New(os.Stderr, "PLAYER: ", log.LstdFlags)
)

type config struct {
	masterQueryURL string
}

func appConfig() (*config, error) {
	configURL := os.Getenv("CAMLI_APP_CONFIG_URL")
	if configURL == "" {
		return nil, fmt.Errorf("Player application needs a CAMLI_APP_CONFIG_URL env var")
	}
	conf := &config{}
	masterQueryURL := os.Getenv("CAMLI_APP_MASTERQUERY_URL")
	if masterQueryURL == "" {
		logger.Fatalf("Player application needs a CAMLI_APP_MASTERQUERY_URL env var")
	}
	conf.masterQueryURL = masterQueryURL

	cl, err := app.Client()
	if err != nil {
		return nil, fmt.Errorf("could not get a client to fetch extra config: %v", err)
	}

	pause := time.Second
	giveupTime := time.Now().Add(time.Hour)
	for {
		err := cl.GetJSON(context.TODO(), configURL, conf)
		if err == nil {
			break
		}
		if time.Now().After(giveupTime) {
			logger.Fatalf("Giving up on starting: could not get app config at %v: %v", configURL, err)
		}
		logger.Printf("could not get app config at %v: %v. Will retry in a while.", configURL, err)
		time.Sleep(pause)
		pause *= 2
	}
	return conf, nil
}

type playerHandler struct {
	masterQueryURL     string
	masterQueryMu      sync.Mutex
	masterQueryResults []audioData

	client *client.Client
	auth   auth.AuthMode
}

type audioData struct {
	BlobRef   string
	Artist    string
	Title     string
	Album     string
	Genre     string
	MediaType string
}

var masterQuery = &search.SearchQuery{
	Limit: -1,
	Constraint: &search.Constraint{
		File: &search.FileConstraint{
			MIMEType: &search.StringConstraint{
				HasPrefix: "audio/",
			},
		},
	},
	Describe: &search.DescribeRequest{},
}

func newPlayerHandler(conf *config) (*playerHandler, error) {
	client, err := app.Client()
	if err != nil {
		return nil, fmt.Errorf("unable to create app client: %v", err)
	}
	auth, err := app.Auth()
	if err != nil {
		return nil, fmt.Errorf("unable to create app auth: %v", err)
	}

	ph := &playerHandler{
		client:         client,
		auth:           auth,
		masterQueryURL: conf.masterQueryURL,
	}

	if err = ph.registerMasterQuery(); err != nil {
		return nil, fmt.Errorf("unable to register master query: %v", err)
	}
	if err = ph.refreshMasterQueryResults(); err != nil {
		return nil, fmt.Errorf("unable to fetch initial master query results: %v", err)
	}
	go ph.loopRefreshMasterQueryResults()

	return ph, nil
}

func (h *playerHandler) registerMasterQuery() error {
	h.masterQueryMu.Lock()
	defer h.masterQueryMu.Unlock()

	data, err := json.Marshal(masterQuery)
	if err != nil {
		return err
	}
	req, err := http.NewRequest("POST", h.masterQueryURL, bytes.NewReader(data))
	if err != nil {
		return err
	}
	h.auth.AddAuthHeader(req)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	if string(body) != "OK" {
		return fmt.Errorf("error setting master query on app handler: %v", string(body))
	}
	return nil
}

func (h *playerHandler) refreshMasterQueryResults() error {
	h.masterQueryMu.Lock()
	defer h.masterQueryMu.Unlock()

	search, err := h.client.Query(context.Background(), masterQuery)
	if err != nil {
		return fmt.Errorf("unable to search audio files: %v", err)
	}
	audioFiles := make([]audioData, 0)
	for _, blob := range search.Blobs {
		blobMeta := search.Describe.Meta.Get(blob.Blob)
		if !isValidAudioMeta(blobMeta) {
			continue
		}
		audioFiles = append(audioFiles, audioData{
			BlobRef:   blob.Blob.String(),
			Title:     blobMeta.MediaTags["title"],
			Album:     blobMeta.MediaTags["album"],
			Artist:    blobMeta.MediaTags["artist"],
			Genre:     blobMeta.MediaTags["genre"],
			MediaType: blobMeta.File.MIMEType,
		})
	}
	h.masterQueryResults = audioFiles

	return nil
}

func isValidAudioMeta(blobMeta *search.DescribedBlob) bool {
	hasMediaTag := func(k string) bool {
		_, ok := blobMeta.MediaTags[k]
		return ok
	}
	return blobMeta.BlobRef.Valid() &&
		hasMediaTag("title") &&
		hasMediaTag("album") &&
		hasMediaTag("artist")

}

func (h *playerHandler) loopRefreshMasterQueryResults() {
	for range time.Tick(time.Minute) {
		if err := h.refreshMasterQueryResults(); err != nil {
			logger.Printf("unable to refresh master query results: %v", err)
			continue
		}
	}
}

// TODO: proper endpoint
func (h *playerHandler) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	h.masterQueryMu.Lock()
	defer h.masterQueryMu.Unlock()

	rw.Header().Add("Content-Type", "application/json")
	json.NewEncoder(rw).Encode(h.masterQueryResults)
}

//go:embed player
var staticFiles embed.FS

func main() {
	flag.Parse()

	logger.Printf("player version %s; Go %s (%s/%s)",
		buildinfo.Summary(),
		runtime.Version(),
		runtime.GOOS,
		runtime.GOARCH,
	)

	if *flagVersion {
		return
	}

	listenAddr, err := app.ListenAddress()
	if err != nil {
		logger.Fatalf("listen address: %v", err)
	}
	conf, err := appConfig()
	if err != nil {
		logger.Fatalf("no app config: %v", err)
	}

	ph, err := newPlayerHandler(conf)
	if err != nil {
		logger.Fatalf("unable to create player handler: %v", err)
	}
	fh := http.FileServer(http.FS(staticFiles))

	// server
	ws := webserver.New()
	ws.Logger = logger
	ws.Handle("/", http.HandlerFunc(func(rw http.ResponseWriter, r *http.Request) {
		switch strings.TrimPrefix(r.URL.Path, "/player") {
		case "/api/meta":
			ph.ServeHTTP(rw, r)
		default:
			fh.ServeHTTP(rw, r)
		}
	}))
	if err := ws.Listen(listenAddr); err != nil {
		logger.Fatalf("listen: %v", err)
	}
	ws.Serve()

}
