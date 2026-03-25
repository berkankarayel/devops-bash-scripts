cat > README.md << 'EOF'
# DevOps Bash Scripts

Gerçek DevOps senaryoları için yazılmış Bash scriptleri.

## Kategoriler

| # | Kategori | Scriptler |
|---|----------|-----------|
| 1 | system/  | Sistem izleme, disk, memory, CPU |
| 2 | users-ssh/ | Kullanıcı yönetimi, SSH |
| 3 | services/ | Servis yönetimi, Nginx, SSL |
| 4 | backup/ | Yedekleme, MinIO |
| 5 | docker-nexus/ | Docker, Nexus |
| 6 | kubernetes/ | K8s yönetimi |
| 7 | gitlab-cicd/ | GitLab, pipeline |
| 8 | logging/ | Log yönetimi, ELK |
| 9 | network/ | Network araçları |
| 10 | advanced/ | Ansible, Terraform, Azure |

## Kullanım

\`\`\`bash
git clone git@github.com:KULLANICIADIN/devops-bash-scripts.git
cd devops-bash-scripts
chmod +x system/01-system-info.sh
./system/01-system-info.sh --log
\`\`\`
EOF