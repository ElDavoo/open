.PHONY: all clean

OUTPUT=socialtext-api.js
FILES=\
        lib/Socialtext/Base.js \
	lib/Socialtext/Account.js \
	lib/Socialtext/Group.js \
	lib/Socialtext/UserAccountRole.js \
	lib/Socialtext/User.js \
	lib/Socialtext/Workspace.js \

TESTS=$(wildcard t/*)

all: $(OUTPUT)

clean:
	rm -f $(OUTPUT)

$(OUTPUT): $(FILES) Makefile
	rm -f $@; \
	for js in $(FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

tests: $(TESTS) $(FILES) Makefile
	$(MAKE) -C ../../../js-test/api
