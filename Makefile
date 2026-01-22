.PHONY: all build clean test run help

VERSION ?= 1.0.0
OUTPUT_DIR ?= dist
EXAMPLE_NAME ?= example

GO ?= go
GOFLAGS ?= -v
LDFLAGS ?= -s -w -X main.Version=$(VERSION) -X main.BuildTime=$(shell date -u '+%Y-%m-%d %H:%M:%S')

PLATFORMS ?= linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64

help:
	@echo "iFlow Auth 构建脚本"
	@echo ""
	@echo "使用方法:"
	@echo "  make build          - 编译当前平台"
	@echo "  make build-all      - 编译所有平台"
	@echo "  make run            - 运行示例程序"
	@echo "  make test           - 运行测试"
	@echo "  make clean          - 清理构建文件"
	@echo "  make release        - 打包所有平台"
	@echo ""
	@echo "参数:"
	@echo "  VERSION=1.0.0       - 设置版本号"
	@echo "  OUTPUT_DIR=dist     - 设置输出目录"

build:
	@echo "编译: $(GOOS)/$(GOARCH)"
	@$(GO) build $(GOFLAGS) -ldflags "$(LDFLAGS)" -o $(OUTPUT_DIR)/$(EXAMPLE_NAME)$(if $(filter windows,$(GOOS)),.exe,) ./cmd/example

build-all:
	@echo "编译所有平台..."
	@$(MAKE) -j $(PLATFORMS)

$(PLATFORMS):
	@echo "编译: $@"
	@$(eval OS=$(word 1,$(subst /, ,$@)))
	@$(eval ARCH=$(word 2,$(subst /, ,$@)))
	@$(eval EXT=$(if $(filter windows,$(OS)),.exe,))
	@$(eval OUT=$(OUTPUT_DIR)/$(EXAMPLE_NAME)-$(OS)-$(ARCH)$(EXT))
	@GOOS=$(OS) GOARCH=$(ARCH) CGO_ENABLED=0 $(GO) build $(GOFLAGS) -ldflags "$(LDFLAGS)" -o $(OUT) ./cmd/example

release: clean
	@echo "打包所有平台..."
	@mkdir -p $(OUTPUT_DIR)
	@$(foreach platform,$(PLATFORMS), \
		$(eval OS=$(word 1,$(subst /, ,$(platform)))) \
		$(eval ARCH=$(word 2,$(subst /, ,$(platform)))) \
		$(eval EXT=$(if $(filter windows,$(OS)),.exe,)) \
		$(eval OUT=$(OUTPUT_DIR)/$(EXAMPLE_NAME)-$(OS)-$(ARCH)$(EXT)) \
		$(eval ARCHIVE=$(OUTPUT_DIR)/$(EXAMPLE_NAME)-$(OS)-$(ARCH).zip) \
		echo "打包: $(OS)/$(ARCH)"; \
		GOOS=$(OS) GOARCH=$(ARCH) CGO_ENABLED=0 $(GO) build $(GOFLAGS) -ldflags "$(LDFLAGS)" -o $(OUT) ./cmd/example; \
		if [ "$(OS)" = "windows" ]; then \
			powershell -Command "Compress-Archive -Path $(OUT) -DestinationPath $(ARCHIVE) -Force"; \
		else \
			mkdir -p $(OUTPUT_DIR)/temp-$(OS)-$(ARCH); \
			cp $(OUT) $(OUTPUT_DIR)/temp-$(OS)-$(ARCH)/$(EXAMPLE_NAME); \
			cd $(OUTPUT_DIR)/temp-$(OS)-$(ARCH) && zip -r ../$(EXAMPLE_NAME)-$(OS)-$(ARCH).zip *; \
			cd ../.. && rm -rf $(OUTPUT_DIR)/temp-$(OS)-$(ARCH); \
		fi; \
		rm -f $(OUT); \
	)
	@echo "打包完成!"

run:
	@$(GO) run ./cmd/example

test:
	@$(GO) test -v ./...

clean:
	@echo "清理构建文件..."
	@rm -rf $(OUTPUT_DIR)
	@$(GO) clean

.DEFAULT_GOAL := help