FROM golang:1.25-bookworm


# Instalar paquetes del sistema necesarios para desarrollo y build de Go
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    gh \
    build-essential \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*


# Configurar git (opcional, puedes personalizar)
RUN git config --global --add safe.directory /workspace
RUN git config --global user.name "osmar"
RUN git config --global user.email "osmargm1202@gmail.com"


# Mantener el directorio de trabajo por defecto de Go
WORKDIR /workspace

