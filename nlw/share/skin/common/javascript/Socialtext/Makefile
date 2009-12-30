.PHONY: all clean

OUTPUT=socialtext-api.js
FILES=\
        base.js \
	account.js \
	group.js \
	useraccountrole.js \
	user.js \
	workspace.js \

all: $(OUTPUT)

clean:
	rm -f $(OUTPUT)

$(OUTPUT): $(FILES) Makefile
	for js in $(FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done
