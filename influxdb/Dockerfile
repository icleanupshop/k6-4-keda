FROM ubuntu

RUN apt-get update

RUN apt-get --assume-yes install curl wget net-tools gpg neovim uuid

RUN wget -O /tmp/go.tar.gz  https://go.dev/dl/go1.20.7.linux-amd64.tar.gz

RUN (cd /usr/local; tar zxvf /tmp/go.tar.gz)

# influxdata-archive_compat.key GPG fingerprint:
#     9D53 9D90 D332 8DC7 D6C8 D3B9 D8FF 8E1F 7DF8 B07E
RUN wget -q https://repos.influxdata.com/influxdata-archive_compat.key
RUN echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
RUN echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdata.list

RUN apt-get update && apt-get --assume-yes install influxdb2

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin:/root/go/bin

RUN go install go.k6.io/xk6/cmd/xk6@latest
RUN (cd /usr/bin/; xk6 build --with github.com/grafana/xk6-output-influxdb)

COPY start.sh / 
RUN chmod 755 /start.sh

ENTRYPOINT /start.sh
