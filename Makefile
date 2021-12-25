
ELM_SRCS := $(shell find client/src -type f -name '*.elm') \
	    client/elm.json \
	    client/gen/GenAccessors.elm
GO_SRCS := $(shell find * -type f -name '*.go') \
	   index.html \
	   style.css

elm_exes := client/elm.opt.js client/elm.debug.js

ELM_MAKE_CMD := cd client && elm make src/Main.elm --output

server_exe := prioritize-app-server

all: $(server_exe) $(elm_exes)

dev: all
	spk dev

dev-local: all
	./run-dev.sh

pack: prioritize.spk

prioritize.spk: all
	spk pack $@

clean:
	rm -f elm.*.js
	rm -f $(server_exe)

$(server_exe): $(GO_SRCS) $(elm_exes)
	go build

client/elm.opt.js: $(ELM_SRCS)
	$(ELM_MAKE_CMD) `basename $@` --optimize
client/elm.debug.js: $(ELM_SRCS)
	$(ELM_MAKE_CMD) `basename $@` --debug
client/gen/GenAccessors.elm: client/gen-accessors.py
	python $< > $@

.PHONY: all clean pack dev dev-local
