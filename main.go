package main

import (
	"crypto/rand"
	_ "embed"
	"errors"
	"fmt"
	"html/template"
	"io"
	"io/fs"
	"io/ioutil"
	"net/http"
	"os"
	"strconv"
	"sync"

	"github.com/gorilla/csrf"
)

var (
	// Where to store our data:
	dataDir = os.Getenv("PAPP_DATA_DIR")

	versionPath = dataDir + "/data-version"

	//go:embed index.html
	templateData string

	//go:embed style.css
	stylesheet []byte

	//go:embed elm.opt.js
	elmOptJs []byte

	//go:embed elm.debug.js
	elmDebugJs []byte
)

type TemplateParams struct {
	Data      string
	CSRFToken string
	Version   int
	Debug     bool
}

func chkfatal(err error) {
	if err != nil {
		panic(err)
	}
}

func getVersion() int {
	data, err := ioutil.ReadFile(versionPath)
	if err != nil {
		return 0
	}
	i, err := strconv.ParseInt(string(data), 10, 64)
	if err != nil {
		return 0
	}
	return int(i)
}

func saveVersion(i int) {
	ioutil.WriteFile(versionPath, []byte(strconv.Itoa(i)), 0600)
}

func getCsrfKey() []byte {
	// load the csrf key from disk, or generate a new one if not found:
	path := dataDir + "/csrfkey"
	data, err := ioutil.ReadFile(path)
	const keyLength = 32
	if err == nil && len(data) == keyLength {
		return data
	}
	if err == nil || errors.Is(err, os.ErrNotExist) {
		// No key yet; generate & save one.
		//
		// if err == nil, that means the key was the wrong length.
		// Maybe that could happen if the write gets truncated
		// when saving? Probably not actually possible with most
		// filesystems though, but we may as well handle it.
		data = make([]byte, keyLength)
		_, err := rand.Read(data)
		chkfatal(err)
		chkfatal(ioutil.WriteFile(path, data, 0600))
		return data
	}
	panic(err)

}

func main() {
	CSRF := csrf.Protect(getCsrfKey())

	data, err := ioutil.ReadFile(dataDir + "/data.json")
	if errors.Is(err, fs.ErrNotExist) {
		data = nil
	} else {
		chkfatal(err)
	}

	indexTemplate := template.Must(template.New("index").Parse(templateData))

	baseTemplateParams := TemplateParams{
		Data:    string(data),
		Version: getVersion(),
	}
	paramsLock := &sync.RWMutex{}
	updateChan := make(chan struct{})

	handleStatic := func(path, contentType string, data []byte) {
		http.HandleFunc(path, func(w http.ResponseWriter, req *http.Request) {
			w.Header().Set("Content-Type", contentType)
			w.Header().Set("Content-Length", strconv.Itoa(len(data)))
			w.Write(data)
		})
	}

	handleStatic("/elm.opt.js", "application/javascript", elmOptJs)
	handleStatic("/elm.debug.js", "application/javascript", elmDebugJs)
	handleStatic("/style.css", "text/css", stylesheet)

	http.Handle("/", CSRF(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		paramsLock.RLock()
		templateParams := baseTemplateParams
		templateParams.Debug = req.URL.Query().Get("debug") == "1"
		paramsLock.RUnlock()
		templateParams.CSRFToken = csrf.Token(req)
		indexTemplate.Execute(w, templateParams)
	})))

	http.Handle("/data", CSRF(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		switch req.Method {
		case "GET":
			paramsLock.Lock()

			versionStr := req.Header.Get("X-Sandstorm-App-Data-Version")
			version, err := strconv.Atoi(versionStr)
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				fmt.Fprintf(w, "Invalid version number: %q", versionStr)
				return
			}
			// Wait for a new version
			newVersion := baseTemplateParams.Version
			for version >= newVersion {
				ch := updateChan
				paramsLock.Unlock()
				select {
				case <-ch:
				case <-req.Context().Done():
					return
				}
				paramsLock.Lock()
				newVersion = baseTemplateParams.Version
			}
			body := []byte(baseTemplateParams.Data)
			paramsLock.Unlock()

			h := w.Header()
			h.Set("Content-Type", "application/json")
			h.Set("Content-Length", strconv.Itoa(len(body)))
			h.Set("X-Sandstorm-App-Data-Version", strconv.Itoa(newVersion))
			// Keep the browser from caching the response.
			h.Set("Cache-Control", "no-store")

			w.WriteHeader(http.StatusOK)
			w.Write(body)
		case "POST":
			newData, err := io.ReadAll(req.Body)
			if err != nil {
				w.Header().Set("Content-Type", "text/plain")
				w.WriteHeader(http.StatusBadRequest)
				w.Write([]byte(err.Error()))
				return
			}

			paramsLock.Lock()
			defer paramsLock.Unlock()
			versionStr := strconv.Itoa(baseTemplateParams.Version)
			if req.Header.Get("X-Sandstorm-App-Data-Version") != versionStr {
				w.WriteHeader(http.StatusConflict)
				return
			}
			baseTemplateParams.Data = string(newData)
			baseTemplateParams.Version++
			close(updateChan)
			updateChan = make(chan struct{})

			w.WriteHeader(http.StatusOK)

			err = ioutil.WriteFile(dataDir+"/data.json.tmp", newData, 0600)
			if err != nil {
				w.Header().Set("Content-Type", "text/plain")
				w.WriteHeader(http.StatusInternalServerError)
				w.Write([]byte(err.Error()))
				return
			}
			saveVersion(baseTemplateParams.Version)
			err = os.Rename(dataDir+"/data.json.tmp", dataDir+"/data.json")
			if err != nil {
				w.Header().Set("Content-Type", "text/plain")
				w.WriteHeader(http.StatusInternalServerError)
				w.Write([]byte(err.Error()))
				return
			}
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
		}
	})))

	panic(http.ListenAndServe(":8000", nil))
}
