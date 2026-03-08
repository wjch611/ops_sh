#!/bin/bash
set -e

echo -e "\033[1;36m========== Server Init Start (2026 优化版) ==========\033[0m"

# 1. 必须 root 执行
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[1;31m请使用 root 执行！\033[0m"
  exit 1
fi

# 2. 设置时区
echo "设置时区为上海..."
timedatectl set-timezone Asia/Shanghai

# 3. 更新系统
echo "更新系统包..."
apt update -y && apt upgrade -y

# 4. 安装基础工具（合并两个版本）
echo "安装基础工具..."
apt install -y vim curl wget git htop net-tools lsof unzip zip \
    bash-completion ca-certificates software-properties-common \
    ufw fail2ban unattended-upgrades sysstat iotop

# 5. 创建运维用户 devops
USERNAME="devops"
if id "$USERNAME" &>/dev/null; then
    echo "用户 $USERNAME 已存在"
else
    echo "创建运维用户 $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    passwd "$USERNAME"
    usermod -aG sudo "$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-$USERNAME
    chmod 0440 /etc/sudoers.d/90-$USERNAME
fi

# 6. SSH 安全加固（强制密钥登录）
echo "SSH 安全加固（禁用密码登录）..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config


systemctl restart ssh

# 7. 防火墙（更严格）
echo "配置 UFW 防火墙..."
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 8. fail2ban + 自动安全更新
echo "配置 fail2ban 与自动安全更新..."
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
maxretry = 5
bantime = 1h
findtime = 10m
EOF
systemctl restart fail2ban
dpkg-reconfigure -f noninteractive unattended-upgrades

# 9. 系统优化（sysctl + swap）
echo "系统优化..."
cat >> /etc/sysctl.conf <<EOF
# 自定义优化
net.core.somaxconn = 1024
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
vm.swappiness = 10
EOF
sysctl -p

# 小内存虚拟机添加 2G swap（VirtualBox 推荐）
if [ $(free -m | awk '/^Mem:/{print $2}') -lt 4096 ]; then
    echo "添加 2G swap..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 10. 清理
apt autoremove -y && apt clean

echo -e "\033[1;32m========== Server Init 完成！ ==========\033[0m"
echo -e "\033[1;33m下一步操作（强烈推荐）：\033[0m"
echo "1. 在你本地电脑生成密钥：ssh-keygen -t ed25519"
echo "2. 把公钥复制到服务器：ssh-copy-id $USERNAME@你的虚拟机IP"
echo "3. 修改sshd_config禁用密码登陆"
