# modern-unix-installer

一个用于自动安装 [modern-unix](https://github.com/ibraheemdev/modern-unix) 工具集的脚本。

## 功能特点

- 支持 Ubuntu/Debian 和 CentOS/RHEL 系统
- 自动检测和安装必要的依赖
- 自动检测 GitHub 访问状态并使用代理
- 使用预编译二进制包，减少编译依赖
- 支持断点续装和跳过已安装工具
- 自动配置工具的常用设置
- 详细的安装日志

## 支持的工具

### 文件操作
- bat (better cat)
- exa (better ls)
- fd-find (better find)
- ripgrep (better grep)

### 系统监控
- bottom (better top/htop)
- duf (better df)
- ncdu (better du)

### 开发工具
- lazygit (git TUI)
- git-delta (better git diff)
- jq (JSON processor)
- fzf (fuzzy finder)

### 其他工具
- zoxide (better cd)
- glow (markdown viewer)
- tldr (better man)

## 使用方法

1. 下载脚本：
```bash
wget https://raw.githubusercontent.com/your-username/modern-unix-installer/main/modern-unix-installer.sh
```

2. 添加执行权限：
```bash
chmod +x modern-unix-installer.sh
```

3. 运行脚本：
```bash
sudo ./modern-unix-installer.sh
```

## 安装选项

脚本提供以下安装选项：
1. 文件操作工具
2. 系统监控工具
3. 开发工具
4. 其他工具
5. 全部安装

## 特性

- 自动检测系统环境
- 智能处理 GitHub 访问问题
- 详细的安装日志 (install.log)
- 安装失败自动重试
- 支持断点续装
- 自动创建命令别名
- 配置 Git 集成

## 注意事项

1. 需要 root 权限或 sudo 运行
2. 确保系统有足够的磁盘空间（建议 > 1GB）
3. 需要稳定的网络连接
4. 某些工具可能需要重新登录才能生效

## 故障排除

1. 如果安装失败，请查看 `install.log` 获取详细信息
2. GitHub 访问问题会自动使用 ghproxy.net 代理
3. 预编译包下载失败会自动尝试其他安装方式

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 致谢

- [modern-unix](https://github.com/ibraheemdev/modern-unix) - 原始工具集合
- [Cursor](https://cursor.sh/) - AI 辅助开发
