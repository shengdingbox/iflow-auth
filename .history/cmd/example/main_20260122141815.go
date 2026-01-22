package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"runtime"
	"time"

	"github.com/router-for-me/iflow-auth/iflow"
)

func main() {
	ctx := context.Background()

	auth := iflow.NewIFlowAuth()

	state := generateRandomState()
	port := findAvailablePort(iflow.CallbackPort)

	authURL, redirectURI := auth.AuthorizationURL(state, port)

	fmt.Println("=== iFlow OAuth 认证示例 ===")
	fmt.Printf("授权 URL: %s\n", authURL)
	fmt.Printf("回调地址: %s\n\n", redirectURI)

	fmt.Println("正在打开浏览器...")
	if err := openBrowser(authURL); err != nil {
		fmt.Printf("无法自动打开浏览器，请手动访问上述链接\n")
	}

	server := iflow.NewOAuthServer(port)
	if err := server.Start(); err != nil {
		log.Fatalf("启动 OAuth 服务器失败: %v", err)
	}
	defer server.Stop(ctx)

	fmt.Println("等待 OAuth 回调...")

	result, err := server.WaitForCallback(5 * time.Minute)
	if err != nil {
		log.Fatalf("等待回调超时或出错: %v", err)
	}

	if result.Error != "" {
		log.Fatalf("OAuth 认证失败: %s", result.Error)
	}

	fmt.Printf("收到授权码: %s\n", result.Code)

	tokenData, err := auth.ExchangeCodeForTokens(ctx, result.Code, redirectURI)
	if err != nil {
		log.Fatalf("交换 token 失败: %v", err)
	}

	fmt.Println("\n=== 认证成功 ===")
	fmt.Printf("Access Token: %s\n", maskToken(tokenData.AccessToken))
	fmt.Printf("Refresh Token: %s\n", maskToken(tokenData.RefreshToken))
	fmt.Printf("API Key: %s\n", maskToken(tokenData.APIKey))
	fmt.Printf("Email: %s\n", tokenData.Email)
	fmt.Printf("过期时间: %s\n", tokenData.Expire)

	storage := auth.CreateTokenStorage(tokenData)
	authFilePath := "iflow-token.json"
	if err := storage.SaveTokenToFile(authFilePath); err != nil {
		log.Printf("保存 token 失败: %v", err)
	} else {
		fmt.Printf("\nToken 已保存到: %s\n", authFilePath)
	}

	fmt.Println("\n=== 刷新 Token 示例 ===")
	refreshedToken, err := auth.RefreshTokens(ctx, tokenData.RefreshToken)
	if err != nil {
		log.Printf("刷新 token 失败: %v", err)
	} else {
		fmt.Printf("刷新后的 Access Token: %s\n", maskToken(refreshedToken.AccessToken))
		fmt.Printf("新的过期时间: %s\n", refreshedToken.Expire)
	}

	fmt.Println("\n=== Cookie 认证示例 ===")
	fmt.Println("如需使用 Cookie 认证，请设置环境变量 IFLOW_COOKIE")
	cookie := os.Getenv("IFLOW_COOKIE")
	if cookie != "" {
		cookieTokenData, err := auth.AuthenticateWithCookie(ctx, cookie)
		if err != nil {
			log.Printf("Cookie 认证失败: %v", err)
		} else {
			fmt.Printf("Cookie 认证成功\n")
			fmt.Printf("API Key: %s\n", maskToken(cookieTokenData.APIKey))
			fmt.Printf("过期时间: %s\n", cookieTokenData.Expire)

			cookieStorage := auth.CreateCookieTokenStorage(cookieTokenData)
			cookieAuthFilePath := "iflow-cookie-token.json"
			if err := cookieStorage.SaveTokenToFile(cookieAuthFilePath); err != nil {
				log.Printf("保存 cookie token 失败: %v", err)
			} else {
				fmt.Printf("Cookie Token 已保存到: %s\n", cookieAuthFilePath)
			}
		}
	}

	fmt.Println("\n示例程序执行完成！")
	fmt.Println("\n按任意键退出...")
	pause()
}

func generateRandomState() string {
	return fmt.Sprintf("state_%d", time.Now().UnixNano())
}

func maskToken(token string) string {

	return token
}

func findAvailablePort(defaultPort int) int {
	addr := fmt.Sprintf(":%d", defaultPort)
	listener, err := net.Listen("tcp", addr)
	if err == nil {
		listener.Close()
		return defaultPort
	}

	for port := 8000; port <= 9000; port++ {
		addr := fmt.Sprintf(":%d", port)
		listener, err := net.Listen("tcp", addr)
		if err == nil {
			listener.Close()
			fmt.Printf("端口 %d 被占用，使用端口 %d\n", defaultPort, port)
			return port
		}
	}

	log.Fatalf("无法找到可用端口 (尝试范围: 8000-9000)")
	return 0
}

func openBrowser(url string) error {
	var cmd string
	var args []string

	switch runtime.GOOS {
	case "windows":
		cmd = "cmd"
		args = []string{"/c", "start"}
	case "darwin":
		cmd = "open"
	default:
		cmd = "xdg-open"
	}
	args = append(args, url)

	return exec.Command(cmd, args...).Start()
}

func pause() {
	fmt.Print("按 Enter 键继续...")
	var input string
	fmt.Scanln(&input)
}
