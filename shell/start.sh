#!/usr/bin/env bash

# 前置依赖 nodejs、npm

if [[ ! $QL_DIR ]]; then
  npm_dir=$(npm root -g)
  pnpm_dir=$(pnpm root -g)
  if [[ -d "$npm_dir/@whyour/qinglong" ]]; then
    QL_DIR="$npm_dir/@whyour/qinglong"
  elif [[ -d "$pnpm_dir/@whyour/qinglong" ]]; then
    QL_DIR="$pnpm_dir/@whyour/qinglong"
  else
    echo -e "未找到 qinglong 模块，请先执行 npm i -g @whyour/qinglong 安装"
  fi

  if [[ $QL_DIR ]]; then
    echo -e "请先执行 export QL_DIR=$QL_DIR，并将 QL_DIR 添加到环境变量"
  fi

  exit 1
fi

# 安装依赖
os_name=$(bash /etc/os-release && echo "$ID")

# alpine
if [[ $os_name == 'alpine' ]]; then
  set -x
  sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
  apk update -f
  apk upgrade
  apk --no-cache add -f bash \
    coreutils \
    moreutils \
    git \
    curl \
    wget \
    tzdata \
    perl \
    openssl \
    jq \
    openssh \
    procps \
    netcat-openbsd
fi

# debian/ubuntu
if [[ $os_name == 'debian' ]] || [[ $os_name == 'ubuntu' ]]; then
  set -x
  sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
  apt update
  apt upgrade -y
  apt install --no-install-recommends -y moreutils \
    git \
    curl \
    wget \
    jq \
    procps \
    netcat
fi

# centos
# ...

npm install -g pnpm@8.3.1
cd && pnpm config set registry https://registry.npmmirror.com
pnpm add -g pm2 tsx

cd ${QL_DIR}
cp -f .env.example .env
chmod 777 ${QL_DIR}/shell/*.sh

. ${QL_DIR}/shell/share.sh

fix_config

pm2 l &>/dev/null

patch_version
if [[ $PipMirror ]]; then
  pip3 config set global.index-url $PipMirror
fi
current_npm_registry=$(cd && pnpm config get registry)
is_equal_registry=$(echo $current_npm_registry | grep "${NpmMirror}")
if [[ "$is_equal_registry" == "" ]]; then
  cd && pnpm config set registry $NpmMirror
  pnpm install -g
fi
update_depend

reload_pm2

if [[ $AutoStartBot == true ]]; then
  nohup ql -l bot >$dir_log/bot.log 2>&1 &
fi

if [[ $EnableExtraShell == true ]]; then
  nohup ql -l extra >$dir_log/extra.log 2>&1 &
fi
