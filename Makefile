
ELM_SRCS := $(shell find src -type f -name '*.elm')

ELM_MAKE_CMD := elm make src/Main.elm --output

all: elm.opt.js

clean:
	rm -f elm.*.js

elm.opt.js: $(ELM_SRCS) elm.json
	$(ELM_MAKE_CMD) $@ --optimize
elm.debug.js: $(ELM_SRCS) elm.json
	$(ELM_MAKE_CMD) $@ --debug

.PHONY: all clean
