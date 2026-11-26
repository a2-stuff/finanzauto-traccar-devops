# Imagen propia para construir y escanear en CI, y promover la misma
# etiqueta (SHA del commit) de Dev a Prod. Parte de Traccar 6.17.0.
FROM traccar/traccar:6.17.0-debian

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq ca-certificates unzip \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install -i /usr/local/aws-cli -b /usr/local/bin \
    && rm -rf /tmp/aws /tmp/awscliv2.zip /var/lib/apt/lists/*

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Puerto web y OsmAnd (simulador GPS)
EXPOSE 8082 5055
ENTRYPOINT ["/entrypoint.sh"]
