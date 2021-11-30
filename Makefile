
ELM_SRCS := $(shell find client/src -type f -name '*.elm') client/elm.json
GO_SRCS := $(shell find server -type f -name '*.go') server/index.html

ELM_MAKE_CMD := cd client && elm make src/Main.elm --output

server_exe := server/prioritize-app-server

all: client/elm.opt.js client/elm.debug.js $(server_exe)

$(server_exe): $(GO_SRCS)
	cd server && go build

clean:
	rm -f elm.*.js
	rm -f $(server_exe)

client/elm.opt.js: $(ELM_SRCS)
	$(ELM_MAKE_CMD) `basename $@` --optimize
client/elm.debug.js: $(ELM_SRCS)
	$(ELM_MAKE_CMD) `basename $@` --debug

.PHONY: all clean
