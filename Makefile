
ELM_SRCS := $(shell find client/src -type f -name '*.elm') client/elm.json

ELM_MAKE_CMD := cd client && elm make src/Main.elm --output

all: client/elm.opt.js

clean:
	rm -f elm.*.js

elm.opt.js: $(ELM_SRCS)
	$(ELM_MAKE_CMD) $@ --optimize
elm.debug.js: $(ELM_SRCS)
	$(ELM_MAKE_CMD) $@ --debug

.PHONY: all clean
