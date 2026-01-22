param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

$ProjectName = "iflow-auth"
$ExampleName = "example"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  iFlow Auth 打包脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$Platforms = @(
    @{OS = "windows"; Arch = "amd64"; Ext = ".exe"},
    @{OS = "windows"; Arch = "arm64"; Ext = ".exe"},
    @{OS = "linux"; Arch = "amd64"; Ext = ""},
    @{OS = "linux"; Arch = "arm64"; Ext = ""},
    @{OS = "darwin"; Arch = "amd64"; Ext = ""},
    @{OS = "darwin"; Arch = "arm64"; Ext = ""}
)

if (Test-Path $OutputDir) {
    Write-Host "清理输出目录: $OutputDir" -ForegroundColor Yellow
    Remove-Item -Path $OutputDir -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputDir | Out-Null

foreach ($Platform in $Platforms) {
    $OS = $Platform.OS
    $Arch = $Platform.Arch
    $Ext = $Platform.Ext
    
    $OutputName = "${ExampleName}-${OS}-${Arch}${Ext}"
    $OutputPath = Join-Path $OutputDir $OutputName
    
    Write-Host "编译: $OS/$Arch" -ForegroundColor Green
    
    $Env:GOOS = $OS
    $Env:GOARCH = $Arch
    $Env:CGO_ENABLED = "0"
    
    $BuildTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LdFlags = "-s -w -X main.Version=$Version -X main.BuildTime=$BuildTime"
    
    go build -ldflags="$LdFlags" -o $OutputPath ./cmd/example
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "编译失败: $OS/$Arch" -ForegroundColor Red
        exit 1
    }
    
    $ArchiveName = "${ExampleName}-${OS}-${Arch}.zip"
    $ArchivePath = Join-Path $OutputDir $ArchiveName
    
    Write-Host "打包: $ArchiveName" -ForegroundColor Green
    
    if ($OS -eq "windows") {
        Compress-Archive -Path $OutputPath -DestinationPath $ArchivePath -Force
    } else {
        $TempDir = Join-Path $OutputDir "temp-$OS-$Arch"
        New-Item -ItemType Directory -Path $TempDir | Out-Null
        Copy-Item -Path $OutputPath -Destination (Join-Path $TempDir $ExampleName)
        Compress-Archive -Path "$TempDir\*" -DestinationPath $ArchivePath -Force
        Remove-Item -Path $TempDir -Recurse -Force
    }
    
    Remove-Item -Path $OutputPath -Force
    
    $FileSize = (Get-Item $ArchivePath).Length / 1KB
    Write-Host "  生成: $ArchiveName ($([math]::Round($FileSize, 2)) KB)" -ForegroundColor Gray
    Write-Host ""
}

$Env:GOOS = ""
$Env:GOARCH = ""
$Env:CGO_ENABLED = ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  打包完成!" -ForegroundColor Green
Write-Host "  输出目录: $OutputDir" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Get-ChildItem -Path $OutputDir -Filter "*.zip" | ForEach-Object {
    $Size = $_.Length / 1KB
    Write-Host "  $($_.Name) ($([math]::Round($Size, 2)) KB)" -ForegroundColor White
}