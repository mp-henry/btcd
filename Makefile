PKG := github.com/btcsuite/btcd

LINT_PKG := github.com/golangci/golangci-lint/cmd/golangci-lint
GOACC_PKG := github.com/ory/go-acc
GOIMPORTS_PKG := golang.org/x/tools/cmd/goimports

GO_BIN := ${GOPATH}/bin
LINT_BIN := $(GO_BIN)/golangci-lint
GOACC_BIN := $(GO_BIN)/go-acc

LINT_COMMIT := v1.18.0
GOACC_COMMIT := 80342ae2e0fcf265e99e76bcc4efd022c7c3811b

DEPGET := cd /tmp && go get -v
GOBUILD := go build -v
GOINSTALL := go install -v 
DEV_TAGS := rpctest
GOTEST_DEV = go test -v -tags=$(DEV_TAGS)
GOTEST := go test -v

GOFILES_NOVENDOR = $(shell find . -type f -name '*.go' -not -path "./vendor/*")

RM := rm -f
CP := cp
MAKE := make
XARGS := xargs -L 1

# Linting uses a lot of memory, so keep it under control by limiting the number
# of workers if requested.
ifneq ($(workers),)
LINT_WORKERS = --concurrency=$(workers)
endif

LINT = $(LINT_BIN) run -v $(LINT_WORKERS)

GREEN := "\\033[0;32m"
NC := "\\033[0m"
define print
	echo $(GREEN)$1$(NC)
endef

default: build

all: build check

# ============
# DEPENDENCIES
# ============

$(LINT_BIN):
	@$(call print, "Fetching linter")
	$(DEPGET) $(LINT_PKG)@$(LINT_COMMIT)

$(GOACC_BIN):
	@$(call print, "Fetching go-acc")
	$(DEPGET) $(GOACC_PKG)@$(GOACC_COMMIT)

goimports:
	@$(call print, "Installing goimports.")
	$(DEPGET) $(GOIMPORTS_PKG)

# ============
# INSTALLATION
# ============

build:
	@$(call print, "Building all binaries")
	$(GOBUILD) $(PKG)
	$(GOBUILD) $(PKG)/cmd/btcctl
	$(GOBUILD) $(PKG)/cmd/gencerts
	$(GOBUILD) $(PKG)/cmd/findcheckpoint
	$(GOBUILD) $(PKG)/cmd/addblock

install:
	@$(call print, "Installing all binaries")
	$(GOINSTALL) $(PKG)
	$(GOINSTALL) $(PKG)/cmd/btcctl
	$(GOINSTALL) $(PKG)/cmd/gencerts
	$(GOINSTALL) $(PKG)/cmd/findcheckpoint
	$(GOINSTALL) $(PKG)/cmd/addblock

release-install:
	@$(call print, "Installing btcd and btcctl release binaries")
	env CGO_ENABLED=0 $(GOINSTALL) -trimpath -ldflags="-s -w -buildid=" $(PKG)
	env CGO_ENABLED=0 $(GOINSTALL) -trimpath -ldflags="-s -w -buildid=" $(PKG)/cmd/btcctl

# =======
# TESTING
# =======

check: unit

unit:
	@$(call print, "Running unit tests.")
	$(GOTEST_DEV) ./... -test.timeout=20m
	cd address; $(GOTEST_DEV) ./... -test.timeout=20m
	cd btcec; $(GOTEST_DEV) ./... -test.timeout=20m
	cd btcutil; $(GOTEST_DEV) ./... -test.timeout=20m
	cd chaincfg; $(GOTEST_DEV) ./... -test.timeout=20m
	cd chainhash; $(GOTEST_DEV) ./... -test.timeout=20m
	cd txscript; $(GOTEST_DEV) ./... -test.timeout=20m
	cd psbt; $(GOTEST_DEV) ./... -test.timeout=20m
	cd wire; $(GOTEST_DEV) ./... -test.timeout=20m

unit-cover: $(GOACC_BIN)
	@$(call print, "Running unit coverage tests.")
	$(GOACC_BIN) ./...
	
	# We need to remove the /v2 pathing from the module to have it work
	# nicely with the CI tool we use to render live code coverage.
	cd address; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd btcec; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd btcutil; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd chaincfg; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd chainhash; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd txscript; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd psbt; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt
	cd wire; $(GOACC_BIN) ./...; sed -i.bak 's/v2\///g' coverage.txt

unit-race:
	@$(call print, "Running unit race tests.")
	env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd address; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd btcec; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd btcutil; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd chaincfg; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd chainhash; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd txscript; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd psbt; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...
	cd wire; env CGO_ENABLED=1 GORACE="history_size=7 halt_on_errors=1" $(GOTEST) -race -test.timeout=20m ./...

# =========
# UTILITIES
# =========

fmt: goimports
	@$(call print, "Fixing imports.")
	goimports -w $(GOFILES_NOVENDOR)
	@$(call print, "Formatting source.")
	gofmt -l -w -s $(GOFILES_NOVENDOR)

lint: $(LINT_BIN)
	@$(call print, "Linting source.")
	$(LINT)

clean:
	@$(call print, "Cleaning source.$(NC)")
	find . -name coverage.txt | xargs echo
	find . -name coverage.txt.bak | xargs echo

.PHONY: all \
	default \
	build \
	check \
	unit \
	unit-cover \
	unit-race \
	fmt \
	lint \
	clean
