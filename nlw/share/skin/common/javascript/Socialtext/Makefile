.PHONY: all clean

OUTPUT=socialtext-api.js
FILES=\
        base.js \
	account.js \
	group.js \
	useraccountrole.js \
	user.js \
	workspace.js \

$(OUTPUT): $(FILES) Makefile
	rm -f $@;
	for js in $(FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done
