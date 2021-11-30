package main

import (
	_ "embed"
	"html/template"
	"io"
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
	chkfatal(err)

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
		// TODO: write to disk.
	})

	panic(http.ListenAndServe(":8000", nil))
}
