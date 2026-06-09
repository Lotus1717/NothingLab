# SSL 证书（仅部署时临时存放）

从 [腾讯云 SSL 证书控制台](https://console.cloud.tencent.com/ssl) 下载 **Nginx** 格式后，临时放于此目录再执行 `deploy_ssl.sh`。

**部署完成后请删除本机副本**（私钥只保留在服务器 `/etc/nginx/ssl/`）。续签时从腾讯云重新下载即可。
