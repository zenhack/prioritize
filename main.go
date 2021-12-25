package main

import (
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
)

var (
	// Where to store our data:
	dataPath = os.Getenv("PAPP_DATA")

	// Path to javascript to load:
	jsPath = os.Getenv("PAPP_JSPATH")

	//go:embed index.html
	templateData string

	//go:embed style.css
	stylesheet []byte
)

type TemplateParams struct {
	Data string
}

func chkfatal(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	data, err := ioutil.ReadFile(dataPath)
	if errors.Is(err, fs.ErrNotExist) {
		data = nil
	} else {
		chkfatal(err)
	}

	jsSrc, err := ioutil.ReadFile(jsPath)
	chkfatal(err)

	indexTemplate := template.Must(template.New("index").Parse(templateData))

	templateParams := &TemplateParams{
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

	http.HandleFunc("/", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		paramsLock.RLock()
		defer paramsLock.RUnlock()
		indexTemplate.Execute(w, templateParams)
	})

	http.HandleFunc("/data", func(w http.ResponseWriter, req *http.Request) {
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
		defer paramsLock.Unlock()
		templateParams.Data = string(newData)
		err = ioutil.WriteFile(dataPath+".tmp", newData, 0600)
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return
		}
		err = os.Rename(dataPath+".tmp", dataPath)
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return
		}
	})

	panic(http.ListenAndServe(":8000", nil))
}
