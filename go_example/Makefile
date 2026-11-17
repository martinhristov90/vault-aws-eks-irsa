.PHONY: all build build-amd64 build-arm64 upload run clean

TARGET_ARCH ?= amd64
POD_NAMESPACE ?= default
POD_NAME ?= $(shell kubectl get pods -n $(POD_NAMESPACE) --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep '^consume-pod' | head -n 1)
BINARY_NAME ?= vault-go-consumer

all: build

build:
	CGO_ENABLED=0 GOOS=linux GOARCH=$(TARGET_ARCH) go build -ldflags="-s -w" -o bin/$(BINARY_NAME) main.go

build-amd64:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bin/$(BINARY_NAME) main.go

build-arm64:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o bin/$(BINARY_NAME) main.go

upload: build
	@if [ -z "$(POD_NAME)" ]; then echo "Error: No pod starting with consume-pod found in namespace $(POD_NAMESPACE)"; exit 1; fi
	@echo "Uploading to pod $(POD_NAME)..."
	kubectl cp bin/$(BINARY_NAME) $(POD_NAMESPACE)/$(POD_NAME):/tmp/$(BINARY_NAME)
	kubectl exec -n $(POD_NAMESPACE) $(POD_NAME) -- chmod +x /tmp/$(BINARY_NAME)

run: upload
	kubectl exec -it -n $(POD_NAMESPACE) $(POD_NAME) -- /tmp/$(BINARY_NAME)

clean:
	rm -rf bin/
