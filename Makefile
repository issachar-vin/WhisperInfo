ADDON   := WhoAreYouPeople
FILES   := $(ADDON).toc $(ADDON).lua icon.tga
VERSION := $(shell sed -n 's/^\#\# Version: *//p' $(ADDON).toc | tr -d '\r')
ZIP     := release/$(ADDON)-$(VERSION).zip

.PHONY: release clean

release: $(ZIP)

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
