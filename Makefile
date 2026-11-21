ADDON   := WhoAreYouPeople
FILES   := $(ADDON).toc $(ADDON).lua icon.tga
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
	$(LUAC) -p $(ADDON).lua
	$(LUA) tests/smoke.lua $(ADDON).lua
	@for style in $(STYLES); do $(LUA) tests/smoke.lua $(ADDON).lua $$style || exit 1; done

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
