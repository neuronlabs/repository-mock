GIT_DIRTY  	= $(shell test -n "`git status --porcelain`" && echo "dirty" || echo "clean")

GOPATH		= $(shell go env GOPATH)
GOLINTCI	= $(GOPATH)/bin/golangci-lint 
MISSPELL	= $(GOPATH)/bin/misspell

GO 		 = go
TIMEOUT  = 20
PKGS     = $(or $(PKG),$(shell env GO111MODULE=on $(GO) list ./...))
TESTPKGS = $(shell env GO111MODULE=on $(GO) list -f \
            '{{ if or .TestGoFiles .XTestGoFiles }}{{ .ImportPath }}{{ end }}' \
            $(PKGS))

Q = $(if $(filter 1,$V),,@)
M = $(shell printf "\033[34;1m▶\033[0m")

DESCRIBE           := $(shell git describe --match "v*" --always --tags)
DESCRIBE_PARTS     := $(subst -, ,$(DESCRIBE))

VERSION_TAG        := $(word 1,$(DESCRIBE_PARTS))
COMMITS_SINCE_TAG  := $(word 2,$(DESCRIBE_PARTS))

VERSION            := $(subst v,,$(VERSION_TAG))
VERSION_PARTS      := $(subst ., ,$(VERSION))

MAJOR              := $(word 1,$(VERSION_PARTS))
MINOR              := $(word 2,$(VERSION_PARTS))
MICRO              := $(word 3,$(VERSION_PARTS))

CURRENT_VERSION    = $(MAJOR).$(MINOR).$(MICRO)
CURRENT_TAG        = v$(CURRENT_VERSION)
NEXT_VERSION	   := $

NEXT_MAJOR         := $(shell echo $$(($(MAJOR)+1)))
NEXT_MINOR         := $(shell echo $$(($(MINOR)+1)))
NEXT_MICRO         := $(shell echo $$(($(MICRO)+$(COMMITS_SINCE_TAG))))

DATE                = $(shell date +'%d.%m.%Y')
TIME                = $(shell date +'%H:%M:%S')
COMMIT             := $(shell git rev-parse HEAD)
AUTHOR             := $(firstword $(subst @, ,$(shell git show --format="%aE" $(COMMIT))))
BRANCH_NAME        := $(shell git rev-parse --abbrev-ref HEAD)

TAG_MESSAGE         = "$(TIME) $(DATE) $(AUTHOR) $(BRANCH_NAME)"
COMMIT_MESSAGE     := $(shell git log --format=%B -n 1 $(COMMIT))

dirty = "dirty"

RELEASE_TARGETS = release-patch release-minor release-major
.PHONY: $(RELEASE_TARGETS) release
$(RELEASE_TARGETS): latest-core test-race lint commit
release-patch: version-patch
release-minor: version-minor
release-major: version-major
$(RELEASE_TARGETS): create-tag push-tag push-develop

.PHONY: create-tag
create-tag:
	$(info $(M) creating tag: '${CURRENT_TAG}'…)
	git tag -a ${CURRENT_TAG} -m ${TAG_MESSAGE}
.PHONY: push-develop
push-develop:
	$(info $(M) pushing to origin/develop…)
	@git push origin develop

.PHONY: push-tag
push-tag:
	$(info $(M) pushing to origin/${CURRENT_TAG}…)
	@git push origin ${CURRENT_TAG}


## check git status
.PHONY: check
check:
	$(info $(M) checking git status…)
ifeq ($(GIT_DIRTY), dirty)
	$(error git state is not clean)
endif

.PHONY: commit
commit:
ifeq ($(GIT_DIRTY), dirty)
	$(info $(M) preparing commit…)
	@git add .
	@git commit -am "$(COMMIT_MESSAGE)"
else ifeq ($(strip $(COMMITS_SINCE_TAG)),)
	$(error no changes from the previous tag)
endif

.PHONY: info
info:
	@echo "Git Commit:        ${COMMIT}"
	@echo "Git Tree State:    ${GIT_DIRTY}"

## Todos
.PHONY: todo
todo:
	@grep \
		--exclude-dir=vendor \
		--exclude=Makefile \
		--exclude=*.swp \
		--text \
		--color \
		-nRo -E ' TODO:.*|SkipNow' .

## Tests
TEST_TARGETS := test-default test-bench test-short test-verbose test-race
.PHONY: $(TEST_TARGETS) test
test-bench:   ARGS=-run=__absolutelynothing__ -bench=. ## Run benchmarks
test-short:   ARGS=-short        ## Run only short tests
test-verbose: ARGS=-v            ## Run tests in verbose mode with coverage reporting
test-race:    ARGS=-race         ## Run tests with race detector
$(TEST_TARGETS): NAME=$(MAKECMDGOALS:test-%=%)
$(TEST_TARGETS): test
test:
	$(info $(M) running $(NAME:%=% )tests…) @ ## Run tests
	$Q $(GO) test -timeout $(TIMEOUT)s $(ARGS) $(TESTPKGS)

## Format
.PHONY: fmt
fmt: ; $(info $(M) running gofmt…) @ ## Run gofmt on all source files
	$Q $(GO) fmt $(PKGS)

## Linters
.PHONY: lint
lint:
	$(info $(M) running linters…)
	@$(GOLINTCI) run ./...
	@$(MISSPELL) -error **/*

.PHONY: latest-core
latest-core:
	go get github.com/neuronlabs/neuron-core@latest

VERSIONS := version-patch version-minor version-major
.PHONY: $(VERSIONS) current-tag
version-patch:
ifneq ($(strip $(COMMITS_SINCE_TAG)),)
	$(info $(M) commits_since_tag $(COMMITS_SINCE_TAG))
	$(info $(M) current version to $(CURRENT_VERSION))
	$(info $(M) next micro: $(NEXT_MICRO))
	$(shell CURRENT_VERSION=$(MAJOR).$(MINOR).$(NEXT_MICRO))
	$(info $(M) setting version to $(CURRENT_VERSION))
endif
version-minor:
ifneq ($(strip $(COMMITS_SINCE_TAG)),)
	@CURRENT_VERSION=$(MAJOR).$(NEXT_MINOR).0
endif
version-major:
ifneq ($(strip $(COMMITS_SINCE_TAG)),)
	@CURRENT_VERSION=$(NEXT_MAJOR).0.0
endif
$(VERSIONS): current-tag

current-tag:
	@CURRENT_TAG=v$(CURRENT_VERSION)
