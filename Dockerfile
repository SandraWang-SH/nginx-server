FROM openresty/openresty:latest

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget software-properties-common \
    curl \
    wget \
    tar \
    git \
    vim \
    unzip \
    net-tools \
    apt-utils \
    && rm -rf /var/lib/apt/lists/*

RUN update-ca-certificates
RUN echo 'deb http://deb.debian.org/debian bullseye main' > /etc/apt/sources.list.d/debian.list

# Update the package manager again and install build-essential
RUN apt-get update && \
    apt-get install -y build-essential libz-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# install LuaRocks
RUN wget --no-check-certificate https://luarocks.org/releases/luarocks-3.9.1.tar.gz && \
    tar zxpf luarocks-3.9.1.tar.gz && \
    cd luarocks-3.9.1 && \
    ./configure && \
    make build && \
    make install && \
    cd .. && \
    rm -rf luarocks-3.9.1 luarocks-3.9.1.tar.gz

RUN addgroup --system nginx \
    && adduser --system --home /var/cache/nginx --ingroup nginx --shell /bin/false --gecos "nginx user" --disabled-password --no-create-home nginx


RUN luarocks install lua-resty-http

RUN luarocks install lua-resty-openssl

RUN cp /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf.bak
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

COPY shadow_invoke.lua /app/shadow_invoke.lua

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

CMD [ "/bin/bash", "-c", "/app/entrypoint.sh" ]
