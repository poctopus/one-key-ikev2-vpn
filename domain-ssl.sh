#!/bin/bash

#可以直接用远程命令执行
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/poctopus/one-key-ikev2-vpn/master/domain-ssl.sh)"
# 定义 account.conf 文件路径
account_conf="/root/.acme.sh/account.conf"

# 定义菜单选项
echo "请选择操作:"
echo "1) 安装和配置 acme.sh"
echo "2) 签发证书"
read -p "输入选项编号 (1 或 2): " choice

# 判断用户选择并执行相应操作
case $choice in
    1)
        # 手工输入 email, domain, cf_token, cf_accountid
        read -p "请输入 Email: " email
        read -p "请输入 Cloudflare Token: " cf_token
        read -p "请输入 Cloudflare Account ID: " cf_accountid

        # 选择默认 CA 选项
        echo "请选择默认 CA:"
        echo "1) ZeroSSL（90天）"
        echo "2) Buypass（180天）"
        echo "3) Google（90天）"
        echo "4) Let's Encrypt（90天）"
        echo "5) SSL.com（90天）"
        read -p "输入选项编号 (1, 2 或 3): " ca_choice

        # 根据选择设置 CA
        case $ca_choice in
            1) default_ca="zerossl" ;;
            2) default_ca="buypass" ;;
            3) default_ca="google" ;;
            4) default_ca="letsencrypt" ;;
            5) default_ca="sslcom" ;;
            *)
                echo "无效选项，请输入 1, 2 或 3。"
                exit 1
                ;;
        esac
        
        # 检查是否已经安装 acme.sh
        if command -v acme.sh >/dev/null 2>&1 || [ -d "/root/.acme.sh" ]; then
            echo "acme.sh 已经安装，跳过安装步骤。"
        else
            # 如果没有安装，执行安装命令
            echo "acme.sh 未安装，开始安装..."
            curl https://get.acme.sh | sh -s email=$email
        fi

        # 设置默认 CA，使用绝对路径执行 acme.sh（默认使用zerossl证书，如果对证书有效期有需求的，域名不多的，可以切换未buypass的CA）
        /root/.acme.sh/acme.sh --set-default-ca --server $default_ca

        # 检查并修改 account.conf 文件
        if ! grep -q "CF_Token" "$account_conf"; then
            echo "export CF_Token=\"$cf_token\"" >> "$account_conf"
        else
            echo "CF_Token 已存在于 account.conf 中，跳过写入。"
        fi

        if ! grep -q "CF_Account_ID" "$account_conf"; then
            echo "export CF_Account_ID=\"$cf_accountid\"" >> "$account_conf"
        else
            echo "CF_Account_ID 已存在于 account.conf 中，跳过写入。"
        fi

        # 提示完成安装和配置
        echo "acme.sh 安装和配置完成。"
        ;;
    2)
        # 进行证书签发
        read -p "请输入 Domain: " domain

        # 加载环境变量
        if [ -f "$account_conf" ]; then
            source "$account_conf"
        else
            echo "未找到 account.conf 文件，请先运行安装和配置选项。"
            exit 1
        fi

        # 执行证书签发
        rm /root/.acme.sh/$domain/
        /root/.acme.sh/acme.sh --issue --dns dns_cf --dnssleep 30 -d $domain -k 2048
        # 检查是否生成了对应的证书文件
        if [ -f "/root/.acme.sh/$domain/$domain.cer" ]; then
            echo "证书生成成功。清理旧的 .pem 文件..."
            rm -f /usr/local/etc/ipsec.d/cacerts/*.pem
            rm -f /usr/local/etc/ipsec.d/certs/*.pem
            rm -f /usr/local/etc/ipsec.d/private/*.pem
            cp /root/.acme.sh/$domain/$domain.cer /usr/local/etc/ipsec.d/certs/server.cert.pem
            cp /root/.acme.sh/$domain/$domain.cer /usr/local/etc/ipsec.d/certs/client.cert.pem
            cp /root/.acme.sh/$domain/$domain.key /usr/local/etc/ipsec.d/private/server.pem
            cp /root/.acme.sh/$domain/$domain.key /usr/local/etc/ipsec.d/private/client.pem
            cp /root/.acme.sh/$domain/ca.cer /usr/local/etc/ipsec.d/cacerts/ca.cert.pem
            ipsec rereadall
            ipsec restart
            echo "证书签发成功，旧证书清理完成、新证书重新加载成功"
        else
            echo "证书生成失败，退出。"
            exit 1
        fi
        ;;
    *)
        echo "无效选项，请输入 1 或 2。"
        exit 1
        ;;
esac
