#!/bin/bash
set -e

# ========== 1. SSH 金鑰：只在「還沒有金鑰」的時候才產生新的 ==========
mkdir -p /home/jenkins/.ssh
if [ ! -f /home/jenkins/.ssh/id_ed25519 ]; then
  echo "[entrypoint] 找不到既有金鑰，產生新的 SSH 金鑰..."
  su - jenkins -c "ssh-keygen -t ed25519 -C 'jenkins-agent' -N '' -f /home/jenkins/.ssh/id_ed25519"
  cp /home/jenkins/.ssh/id_ed25519.pub /home/jenkins/.ssh/authorized_keys
  echo "[entrypoint] ⚠️ 這是全新金鑰，記得把公鑰貼到 Git remote、私鑰貼到 Jenkins Credentials："
  cat /home/jenkins/.ssh/id_ed25519.pub
else
  echo "[entrypoint] 偵測到既有金鑰（來自掛載資料夾），沿用不重新產生"
fi
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/id_ed25519 /home/jenkins/.ssh/authorized_keys 2>/dev/null || true
chmod 644 /home/jenkins/.ssh/id_ed25519.pub 2>/dev/null || true
chown -R jenkins:jenkins /home/jenkins/.ssh

# ========== 2. Downloads 目錄：部分 GUI 測試 Suite（例如 Certificates）需要這個路徑存在 ==========
mkdir -p /home/jenkins/Downloads
chown jenkins:jenkins /home/jenkins/Downloads
chmod 755 /home/jenkins/Downloads

# ========== 3. boot_lists 軟連結：自動掃描所有 Job 的 workspace ==========
# 用途：讓每個 Job workspace 底下的 openbmc-test-automation/data/boot_lists
# 都指向掛載進來的真實測試資材目錄 /data/boot_lists，
# 避免每個 workspace 各自缺少 boot_lists 內容導致測試找不到檔案。
link_boot_lists() {
  find /home/jenkins/workspace -type d -name "openbmc-test-automation" 2>/dev/null | while read -r repo_dir; do
    target="$repo_dir/data/boot_lists"
    if [ -L "$target" ]; then
      : # 已經是軟連結，跳過
    elif [ -e "$target" ]; then
      echo "[entrypoint] ⚠️ $target 是真實檔案/資料夾，不動它，需人工檢查"
    else
      mkdir -p "$repo_dir/data"
      ln -sfn /data/boot_lists "$target"
      echo "[entrypoint] 已建立軟連結: $target"
    fi
  done
  chown -R jenkins:jenkins /home/jenkins/workspace 2>/dev/null || true
}

link_boot_lists

# 背景持續每 60 秒掃描一次：
# Jenkins Pipeline 若在 Checkout 階段使用 cleanWs()，
# 每次 Build 都會清空 workspace，此機制確保連結持續自動補上，
# 不需要每次 Build 後手動介入。
( while true; do sleep 60; link_boot_lists >/dev/null; done ) &

# ========== 4. 啟動 sshd（前景執行，維持容器存活）==========
exec /usr/sbin/sshd -D
