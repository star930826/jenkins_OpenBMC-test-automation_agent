# obmc-agent Docker Image

Jenkins SSH Agent，用於執行 OpenBMC 相關的自動化測試（Redfish / GUI / IBMi / IPMI），
支援 Robot Framework GUI 測試（Firefox + Selenium）與 bmcweb build 環境。

## 這個 Image 裡有什麼

- **基礎環境**：Ubuntu 24.04
- **Java**：OpenJDK 17 / 21（預設使用 21）
- **GUI 測試**：Firefox 112.0.2、Geckodriver 0.33.0、Xvfb（虛擬顯示器）、Chromium
- **Robot Framework 套件**：
  - robotframework
  - robotframework-sshlibrary
  - robotframework-requests
  - robotframework-seleniumlibrary
  - robotframework-angularjs
  - robotframework-scplibrary
  - robotframework-xvfb
  - robotframework-lint / robotframework-robocop
- **其他 Python 套件**：requests、redfish、urllib3、beautifulsoup4、lxml、pyyaml、jsonschema、numpy、pandas
- **系統工具**：git、ipmitool、nmap、snmp、build-essential 等
- **SSH**：OpenSSH Server，支援帳密登入（`jenkins:jenkins`）與金鑰登入

## 檔案說明

| 檔案 | 用途 |
|---|---|
| `Dockerfile` | Image 建置腳本，包含所有套件與環境設定 |
| `entrypoint.sh` | 容器啟動時自動執行，負責 SSH 金鑰處理、`boot_lists` 軟連結自動修復、`Downloads` 目錄建立 |

## entrypoint.sh 做了什麼（重要，會影響行為）

容器每次啟動時會自動執行以下邏輯：

1. **SSH 金鑰**：檢查 `/home/jenkins/.ssh/id_ed25519` 是否存在
   - 不存在 → 自動產生一組新的（並印出公鑰，需手動貼到 GitLab / Jenkins Credentials）
   - 存在（通常是掛載自宿主機的共用資料夾）→ 沿用，不重新產生
2. **`Downloads` 目錄**：自動建立 `/home/jenkins/Downloads`（部分 GUI 測試套件，例如 Certificates，會需要這個路徑存在，否則 Suite Setup 就會整批失敗）
3. **`boot_lists` 軟連結自動修復**：
   - 掃描 `/home/jenkins/workspace` 底下所有名為 `openbmc-test-automation` 的資料夾
   - 若其 `data/boot_lists` 尚未建立軟連結，自動建立指向 `/data/boot_lists` 的軟連結
   - **每 60 秒重新掃描一次**
## 使用方式

### 1. Build image

```bash
git clone <this-repo-url>
cd <repo-folder>
docker build -t obmc-agent:full-24.04 .
```

### 2. 準備宿主機掛載資料夾

```bash
mkdir -p ~/jenkins_data/{jenkins,boot_lists,ssh_shared,workspace}
```

### 3. 啟動容器

```bash
docker run -d \
  --name obmc-agent \
  --restart always \
  --shm-size=2g \
  -p <對外 port>:22 \
  -v /dev/shm:/dev/shm \
  -v ~/jenkins_data/jenkins:/data/jenkins \
  -v ~/jenkins_data/boot_lists:/data/boot_lists \
  -v ~/jenkins_data/ssh_shared:/home/jenkins/.ssh \
  -v ~/jenkins_data/workspace:/home/jenkins/workspace \
  obmc-agent:full-24.04

docker network connect jenkins-net obmc-agent
```

**掛載參數說明：**

| 掛載 | 作用 |
|---|---|
| `--shm-size=2g` + `-v /dev/shm:/dev/shm` | Firefox/Chromium 需要足夠的共享記憶體，預設 64MB 太小容易 Crash |
| `-v .../boot_lists:/data/boot_lists` | 測試資材（`OS_reboot` 等 boot 清單檔案），需為真實資料，不可留空 |
| `-v .../ssh_shared:/home/jenkins/.ssh` | SSH 金鑰持久化；多台 Agent 可共用同一份資料夾，達成共用金鑰 |
| `-v .../workspace:/home/jenkins/workspace` | 測試截圖 / log 輸出目錄，寫到宿主機硬碟，避免塞爆容器空間 |

### 4. 驗證

```bash
docker logs obmc-agent                                    # 確認 entrypoint 執行狀況
docker exec -u jenkins obmc-agent cat /home/jenkins/.ssh/id_ed25519.pub
docker exec -u jenkins obmc-agent ls -la /data/boot_lists/
docker exec -u jenkins obmc-agent python3 -c "import XvfbRobot; print('OK')"
docker exec -u jenkins obmc-agent firefox --version
docker exec -u jenkins obmc-agent geckodriver --version
docker exec -u jenkins obmc-agent df -h /dev/shm
```

## 已知注意事項

- **Jenkins Job 名稱請避免使用空格**，已確認空格路徑會導致 Pipeline / Robot Framework 部分環節讀取失敗。
- **`gen_misc.py`（openbmc-test-automation repo 內）** 的 `gm.which()` 曾有路徑引號處理問題，修正應 commit 進該 repo，而非僅在 agent 端手動修補，否則每次 `cleanWs()` 後會失效。
- 若容器被 `docker rm` 重建，可寫層資料會歸零；只要掛載參數設定正確（見上方），核心資料（金鑰、boot_lists、workspace）不會遺失。

## 待辦事項

- [ ] 資料掛載路徑搬遷至系統層級路徑（如 `/data/`），避免依賴個人帳號
- [ ] 確認 `gen_misc.py` 修正已 commit 至 `openbmc-test-automation` repo
- [ ] 建立 workspace 定期清理機制，避免長期累積佔滿磁碟
