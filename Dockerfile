FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# ===== 基礎套件 =====
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    openjdk-17-jre-headless \
    openjdk-21-jre-headless \
    git \
    curl \
    wget \
    rsync \
    iputils-ping \
    net-tools \
    ipmitool \
    dnsutils \
    nmap \
    snmp \
    snmpd \
    build-essential \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-setuptools \
    python3-wheel \
    sudo \
    bash \
    nano \
    vim \
    jq \
    xvfb \
    chromium-browser \
    chromium-chromedriver \
    lsb-release \
    tar \
    bzip2 \
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxt6 \
    libpci3 \
    libasound2t64 \
    libx11-xcb1 \
    libxtst6 \
    libxrandr2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libcups2 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java

# ===== Firefox 112.0.2 =====
RUN wget -O /tmp/firefox.tar.bz2 "https://ftp.mozilla.org/pub/firefox/releases/112.0.2/linux-x86_64/en-US/firefox-112.0.2.tar.bz2" && \
    tar -xjf /tmp/firefox.tar.bz2 -C /opt/ && \
    rm /tmp/firefox.tar.bz2 && \
    ln -sf /opt/firefox/firefox /usr/local/bin/firefox

# ===== Geckodriver v0.33.0 =====
RUN wget -O /tmp/geckodriver.tar.gz "https://github.com/mozilla/geckodriver/releases/download/v0.33.0/geckodriver-v0.33.0-linux64.tar.gz" && \
    tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin/ && \
    cp /usr/local/bin/geckodriver /usr/bin/geckodriver && \
    rm /tmp/geckodriver.tar.gz

# ===== 環境變數 =====
ENV MOZ_HEADLESS=1
ENV DISPLAY=:99
ENV MOZ_DISABLE_OOP_SANDBOX=1

# ===== Python / Robot Framework 套件（不升級系統 pip，避免 apt/pip 衝突）=====
RUN pip3 install --no-cache-dir --break-system-packages \
    robotframework \
    robotframework-sshlibrary \
    robotframework-requests \
    robotframework-seleniumlibrary \
    robotframework-angularjs \
    robotframework-scplibrary \
    robotframework-xvfb \
    robotframework-lint \
    robotframework-robocop \
    requests \
    redfish \
    urllib3 \
    beautifulsoup4 \
    lxml \
    pyyaml \
    jsonschema \
    numpy \
    pandas

# ===== jenkins 使用者與 SSH 設定 =====
RUN useradd -m -s /bin/bash jenkins && \
    echo "jenkins:jenkins" | chpasswd && \
    echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    mkdir -p /var/run/sshd /home/jenkins/.ssh && \
    chmod 700 /home/jenkins/.ssh && \
    chown -R jenkins:jenkins /home/jenkins && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# ===== boot_lists 目錄先建空的，真實資料靠 -v 掛進來 =====
RUN mkdir -p /data/boot_lists /usr/local/data/boot_lists && \
    chown -R jenkins:jenkins /data /usr/local/data

# ===== entrypoint：容器啟動時自動處理 SSH 金鑰 + boot_lists 軟連結 =====
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
