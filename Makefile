ADDON   := WhoAreYouPeople
# the Lua files, in load order, straight from the .toc
SOURCES := $(shell sed -n 's/\r$$//; /^[^\#].*\.lua$$/p' $(ADDON).toc)
FILES   := $(ADDON).toc $(SOURCES) icon.tga
VERSION := $(shell sed -n 's/^\#\# Version: *//p' $(ADDON).toc | tr -d '\r')
ZIP     := release/$(ADDON)-$(VERSION).zip
LUA     ?= lua
LUAC    ?= luac

.PHONY: release test clean version

release: test $(ZIP)

STYLES  := forever eui classic blizzard

# Syntax check, then load the addon in a fake WoW environment and fire every
# handler, once with no saved settings and once per UI style.
test:
	$(LUAC) -p $(SOURCES)
	$(LUA) tests/smoke.lua $(ADDON).toc
	@for style in $(STYLES); do $(LUA) tests/smoke.lua $(ADDON).toc $$style || exit 1; done

# Stage under a folder named after the addon so the zip extracts to Interface\AddOns\WhoAreYouPeople\.
$(ZIP): $(FILES)
	rm -rf release/stage
	mkdir -p release/stage/$(ADDON)
	cp $(FILES) release/stage/$(ADDON)/
	rm -f $@
	cd release/stage && zip -rq ../$(notdir $@) $(ADDON)
	rm -rf release/stage
	@echo "Built $@"

clean:
	rm -rf release

version:
	@echo $(VERSION)
