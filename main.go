package main

import (
	"crypto/rand"
	_ "embed"
	"errors"
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

	debugElm = os.Getenv("PAPP_ELM_DEBUG") != ""
	jsPath   = os.Getenv("PAPP_JSPATH")

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
}

func chkfatal(err error) {
	if err != nil {
		panic(err)
	}
}

func getCsrfKey() []byte {
	// load the csrf key from disk, or generate a new one if not found:
	path := dataDir + "/csrfkey"
	data, err := ioutil.ReadFile(dataDir + "/csrfkey")
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

	var jsSrc []byte
	if debugElm {
		jsSrc = elmDebugJs
	} else {
		jsSrc = elmOptJs
	}

	indexTemplate := template.Must(template.New("index").Parse(templateData))

	baseTemplateParams := TemplateParams{
		Data: string(data),
	}
	paramsLock := &sync.RWMutex{}

	http.HandleFunc("/elm.js", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "application/javascript")
		w.Header().Set("Content-Length", strconv.Itoa(len(jsSrc)))
		w.Write(jsSrc)
	})

	http.HandleFunc("/style.css", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "text/css")
		w.Header().Set("Content-Length", strconv.Itoa(len(stylesheet)))
		w.Write(stylesheet)
	})

	http.Handle("/", CSRF(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		paramsLock.RLock()
		templateParams := baseTemplateParams
		paramsLock.RUnlock()
		templateParams.CSRFToken = csrf.Token(req)
		indexTemplate.Execute(w, templateParams)
	})))

	http.Handle("/data", CSRF(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if req.Method != "POST" {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		newData, err := io.ReadAll(req.Body)
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(err.Error()))
			return
		}
		w.WriteHeader(http.StatusOK)

		paramsLock.Lock()
		baseTemplateParams.Data = string(newData)
		paramsLock.Unlock()

		err = ioutil.WriteFile(dataDir+"/data.json.tmp", newData, 0600)
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return
		}
		err = os.Rename(dataDir+"/data.json.tmp", dataDir+"/data.json")
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return
		}
	})))

	panic(http.ListenAndServe(":8000", nil))
}
