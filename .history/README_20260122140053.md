# iFlow Auth

iFlow OAuth 认证库，提供完整的 OAuth 2.0 认证流程实现。

## 功能特性

- OAuth 2.0 授权码流程
- Token 刷新机制
- Cookie 认证支持
- Token 持久化存储
- 自动端口查找
- 跨平台支持

## 项目结构

```
iflow-auth/
├── iflow/                    # 库代码
│   ├── iflow-auth.go        # OAuth 认证实现
│   ├── iflow-token.go       # Token 存储管理
│   └── oauth-server.go      # OAuth 回调服务器
├── cmd/
│   └── example/
│       └── main.go          # 示例程序
├── build.ps1                # Windows 打包脚本
├── Makefile                 # Linux/macOS 构建脚本
└── README.md                # 本文档
```

## 快速开始

### 安装依赖

```bash
go mod download
```

### 运行示例程序

```bash
go run ./cmd/example
```

程序会：
1. 自动查找可用端口（默认 11451，如被占用则自动切换）
2. 生成授权 URL
3. 等待用户在浏览器中完成认证
4. 交换授权码获取 access token
5. 保存 token 到本地文件

### Cookie 认证

设置环境变量后运行：

```powershell
$env:IFLOW_COOKIE="your_cookie_here"
go run ./cmd/example
```

## 构建

### Windows

```powershell
.\build.ps1
```

指定版本号：

```powershell
.\build.ps1 -Version "1.0.0"
```

### Linux/macOS

```bash
make build-all
```

或使用 Makefile：

```bash
make help          # 查看所有命令
make build         # 编译当前平台
make release       # 打包所有平台
make clean         # 清理构建文件
```

## 输出文件

- `iflow-token.json` - OAuth 认证获取的 token
- `iflow-cookie-token.json` - Cookie 认证获取的 token

## 库使用示例

```go
package main

import (
    "context"
    "github.com/router-for-me/iflow-auth/iflow"
)

func main() {
    ctx := context.Background()
    
    auth := iflow.NewIFlowAuth()
    
    state := "random_state"
    port := 8080
    
    authURL, redirectURI := auth.AuthorizationURL(state, port)
    
    server := iflow.NewOAuthServer(port)
    server.Start()
    defer server.Stop(ctx)
    
    result, _ := server.WaitForCallback(5 * time.Minute)
    
    tokenData, _ := auth.ExchangeCodeForTokens(ctx, result.Code, redirectURI)
    
    storage := auth.CreateTokenStorage(tokenData)
    storage.SaveTokenToFile("token.json")
}
```

## API 文档

### IFlowAuth

主要认证客户端，提供 OAuth 认证相关功能。

#### 方法

- `NewIFlowAuth() *IFlowAuth` - 创建新的认证客户端
- `AuthorizationURL(state string, port int) (authURL, redirectURI string)` - 生成授权 URL
- `ExchangeCodeForTokens(ctx, code, redirectURI) (*IFlowTokenData, error)` - 交换授权码获取 token
- `RefreshTokens(ctx, refreshToken) (*IFlowTokenData, error)` - 刷新 token
- `AuthenticateWithCookie(ctx, cookie) (*IFlowTokenData, error)` - Cookie 认证
- `CreateTokenStorage(data) *IFlowTokenStorage` - 创建 token 存储
- `UpdateTokenStorage(storage, data)` - 更新 token 存储

### OAuthServer

OAuth 回调服务器，用于接收 OAuth 回调。

#### 方法

- `NewOAuthServer(port int) *OAuthServer` - 创建新的服务器
- `Start() error` - 启动服务器
- `Stop(ctx) error` - 停止服务器
- `WaitForCallback(timeout) (*OAuthResult, error)` - 等待回调

## 常量

- `CallbackPort = 11451` - 默认回调端口
- `DefaultAPIBaseURL = "https://apis.iflow.cn/v1"` - API 基础 URL
- `SuccessRedirectURL` - 成功重定向 URL

## 注意事项

- 程序会自动查找可用端口，无需手动配置
- Cookie 认证需要从浏览器中获取有效的 iFlow cookie
- Token 文件包含敏感信息，请妥善保管
- 建议在生产环境中使用环境变量管理敏感信息

## 许可证

本项目仅供学习和参考使用。