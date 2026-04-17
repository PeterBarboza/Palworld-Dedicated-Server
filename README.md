# Palworld Dedicated Server (Docker)

Servidor dedicado de Palworld containerizado com Docker. Inclui instalacao automatica via SteamCMD, configuracao por variaveis de ambiente e persistencia de saves.

## Indice

- [Requisitos minimos](#requisitos-minimos)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Provisionamento em VPS Linux](#provisionamento-em-vps-linux)
  - [1. Acesso inicial a VPS](#1-acesso-inicial-a-vps)
  - [2. Atualizacao do sistema](#2-atualizacao-do-sistema)
  - [3. Instalacao do Docker](#3-instalacao-do-docker)
  - [4. Firewall](#4-firewall)
  - [5. Clonar o repositorio](#5-clonar-o-repositorio)
  - [6. Configurar variaveis de ambiente](#6-configurar-variaveis-de-ambiente)
  - [7. Subir o servidor](#7-subir-o-servidor)
  - [8. Verificar se esta rodando](#8-verificar-se-esta-rodando)
  - [9. Parar o servidor](#9-parar-o-servidor)
  - [10. Atualizar o servidor](#10-atualizar-o-servidor)
- [Configuracao no Coolify](#configuracao-no-coolify)
  - [1. Pre-requisitos](#1-pre-requisitos)
  - [2. Criar o servico](#2-criar-o-servico)
  - [3. Configurar variaveis de ambiente](#3-configurar-variaveis-de-ambiente)
  - [4. Configurar portas](#4-configurar-portas)
  - [5. Configurar volume persistente](#5-configurar-volume-persistente)
  - [6. Deploy](#6-deploy)
  - [7. Monitoramento](#7-monitoramento)
- [Variaveis de ambiente](#variaveis-de-ambiente)
  - [Variaveis do container](#variaveis-do-container)
  - [Variaveis do jogo (prefixo PAL_)](#variaveis-do-jogo-prefixo-pal_)
- [Portas](#portas)
- [Volumes e persistencia](#volumes-e-persistencia)
- [Backup dos saves](#backup-dos-saves)
- [Solucao de problemas](#solucao-de-problemas)

---

## Requisitos minimos

| Recurso | Minimo    | Recomendado     |
|---------|-----------|-----------------|
| CPU     | 4 cores   | 4+ cores        |
| RAM     | 8 GB      | 16 GB           |
| Disco   | 30 GB     | 50 GB (SSD)     |
| SO      | Ubuntu 22.04+ / Debian 12+ | Ubuntu 24.04 |
| Rede    | Portas UDP 8211 e 27015 abertas | - |

> O servidor de Palworld consome bastante RAM. Com 16+ jogadores simultaneos, 16 GB e recomendado.

---

## Estrutura do projeto

```
palworld-dedicated-server/
├── Dockerfile              # Imagem baseada em cm2network/steamcmd
├── docker-compose.yml      # Orquestracao (portas, volumes, env vars)
├── .dockerignore
└── scripts/
    └── entrypoint.sh       # Install/update via SteamCMD + config + start
```

**Fluxo de inicializacao do container:**

1. SteamCMD baixa/atualiza o Palworld Dedicated Server (AppID `2394010`)
2. Na primeira execucao, copia `DefaultPalWorldSettings.ini` como config base
3. Aplica overrides de variaveis de ambiente com prefixo `PAL_`
4. Inicia o servidor com as flags configuradas

---

## Provisionamento em VPS Linux

Este guia assume uma VPS com Ubuntu/Debian recem-provisionada (sem nada instalado).

### 1. Acesso inicial a VPS

Conecte via SSH com o IP fornecido pelo seu provedor:

```bash
ssh root@SEU_IP_DA_VPS
```

Crie um usuario nao-root para operar o servidor (boa pratica de seguranca):

```bash
adduser palworld
usermod -aG sudo palworld
su - palworld
```

### 2. Atualizacao do sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Instalacao do Docker

Instale o Docker Engine e o plugin Compose:

```bash
# Dependencias
sudo apt install -y ca-certificates curl gnupg

# Chave GPG oficial do Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Repositorio do Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Permitir uso sem sudo
sudo usermod -aG docker $USER
newgrp docker
```

Verifique a instalacao:

```bash
docker --version
docker compose version
```

> **Debian:** substitua `ubuntu` por `debian` na URL do repositorio acima.

### 4. Firewall

O Palworld precisa das portas UDP abertas. Se estiver usando `ufw`:

```bash
sudo ufw allow 8211/udp comment "Palworld Game Port"
sudo ufw allow 27015/udp comment "Palworld Query Port"
sudo ufw reload
```

Se estiver usando `iptables` diretamente:

```bash
sudo iptables -A INPUT -p udp --dport 8211 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 27015 -j ACCEPT
```

> Verifique tambem o painel de firewall do seu provedor de VPS (Hetzner, DigitalOcean, etc). Muitos tem um firewall externo que precisa ser configurado separadamente.

### 5. Clonar o repositorio

```bash
git clone https://github.com/SEU_USUARIO/palworld-dedicated-server.git
cd palworld-dedicated-server
```

### 6. Configurar variaveis de ambiente

Edite o `docker-compose.yml` e descomente/ajuste as variaveis que desejar:

```bash
nano docker-compose.yml
```

No minimo, configure:

```yaml
environment:
  COMMUNITY_SERVER: "true"
  MULTITHREAD: "true"
  PAL_ServerName: "Meu Servidor Palworld"
  PAL_ServerPassword: "senha_segura"
  PAL_AdminPassword: "senha_admin_segura"
  PAL_ServerPlayerMaxNum: "16"
```

> Veja a secao [Variaveis de ambiente](#variaveis-de-ambiente) para a lista completa.

### 7. Subir o servidor

```bash
docker compose up -d --build
```

A primeira execucao demora mais porque:
- Faz build da imagem Docker
- SteamCMD baixa o servidor (~6 GB)

Acompanhe os logs em tempo real:

```bash
docker compose logs -f
```

Quando aparecer algo como `Setting breakpad minidump AppID = 2394010`, o servidor esta pronto.

### 8. Verificar se esta rodando

```bash
# Status do container
docker compose ps

# Uso de recursos
docker stats palworld-server
```

### 9. Parar o servidor

```bash
docker compose down
```

Os saves sao preservados no volume `palworld-data`.

### 10. Atualizar o servidor

Quando sair uma atualizacao do Palworld, basta recriar o container. O entrypoint roda `steamcmd +app_update` toda vez que inicia:

```bash
docker compose down
docker compose up -d --build
```

---

## Configuracao no Coolify

O [Coolify](https://coolify.io) e uma plataforma open-source de deploy self-hosted. Esta secao explica como configurar o servidor Palworld como um servico Docker Compose dentro do Coolify.

### 1. Pre-requisitos

- Coolify instalado e rodando na sua VPS (ou em outra maquina gerenciando a VPS-alvo)
- O servidor-alvo (onde o Palworld vai rodar) cadastrado como **Server** no Coolify
- Repositorio Git com este projeto (GitHub, GitLab, ou Gitea)
- Portas UDP 8211 e 27015 liberadas no firewall da VPS-alvo

### 2. Criar o servico

1. No painel do Coolify, va em **Projects** e selecione (ou crie) um projeto
2. Dentro do projeto, clique em **+ New** > **Resource**
3. Selecione o servidor-alvo onde o Palworld vai rodar
4. Escolha **Docker Compose** como tipo de deploy
5. Conecte ao seu repositorio Git que contem este projeto
6. O Coolify vai detectar o `docker-compose.yml` automaticamente

### 3. Configurar variaveis de ambiente

Na aba **Environment Variables** do servico no Coolify, adicione as variaveis desejadas:

| Variavel | Valor |
|----------|-------|
| `COMMUNITY_SERVER` | `true` |
| `MULTITHREAD` | `true` |
| `PAL_ServerName` | `Meu Servidor Palworld` |
| `PAL_ServerPassword` | `senha_segura` |
| `PAL_AdminPassword` | `senha_admin_segura` |
| `PAL_ServerPlayerMaxNum` | `16` |

> No Coolify, as variaveis definidas na interface sobrescrevem as do `docker-compose.yml`. Voce pode manter o compose limpo e gerenciar tudo pela interface.

### 4. Configurar portas

O Coolify precisa saber que este servico usa portas UDP diretamente (nao e um servico web com proxy reverso).

Na configuracao do servico:

1. Desative o **Proxy** (Palworld nao usa HTTP — e trafego UDP de jogo direto)
2. Garanta que o mapeamento de portas do `docker-compose.yml` esta sendo respeitado:
   - `8211:8211/udp`
   - `27015:27015/udp`

> O Coolify normalmente gerencia o proxy via Traefik para servicos web. Para servidores de jogo, o proxy deve ser **desabilitado** para que as portas UDP funcionem corretamente via bind direto no host.

### 5. Configurar volume persistente

O volume `palworld-data` definido no `docker-compose.yml` sera criado automaticamente pelo Docker. Ele persiste:

- Saves dos jogadores e do mundo
- Configuracoes do servidor (`PalWorldSettings.ini`)

Os dados sobrevivem a redeploys e restarts pelo Coolify.

Para localizacao manual dos dados no host:

```bash
docker volume inspect palworld-data
```

### 6. Deploy

1. Clique em **Deploy** no painel do Coolify
2. Acompanhe o build e os logs na aba **Logs**
3. O primeiro deploy demora mais (build da imagem + download do servidor via SteamCMD)
4. Deploys subsequentes sao mais rapidos pois o Docker cacheia as camadas da imagem

Para atualizar o servidor de jogo (quando sair patch do Palworld):

1. Va ao servico no Coolify
2. Clique em **Redeploy**
3. O entrypoint executa `steamcmd +app_update` automaticamente e baixa a atualizacao

### 7. Monitoramento

No Coolify voce pode:

- Ver **logs em tempo real** na aba Logs do servico
- Acompanhar **uso de CPU/RAM** do container
- Configurar **health checks** (opcional)
- Receber **notificacoes** de restart/crash via integracoes (Discord, Slack, Email)

---

## Variaveis de ambiente

### Variaveis do container

Controlam o comportamento do entrypoint e flags de inicializacao.

| Variavel | Padrao | Descricao |
|----------|--------|-----------|
| `COMMUNITY_SERVER` | `"true"` | Exibe o servidor na lista de servidores da comunidade |
| `MULTITHREAD` | `"true"` | Ativa otimizacoes multi-thread (`-useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS`) |
| `EXTRA_ARGS` | `""` | Argumentos extras passados diretamente ao `PalServer.sh` |

### Variaveis do jogo (prefixo PAL_)

Qualquer variavel com prefixo `PAL_` e mapeada para uma configuracao no `PalWorldSettings.ini`. O prefixo e removido e o valor e aplicado diretamente.

**Exemplo:** `PAL_ServerName=Meu Server` vira `ServerName=Meu Server` no ini.

Variaveis comuns:

| Variavel | Padrao | Descricao |
|----------|--------|-----------|
| `PAL_ServerName` | `Default Palworld Server` | Nome exibido na lista de servidores |
| `PAL_ServerDescription` | `""` | Descricao do servidor |
| `PAL_ServerPassword` | `""` | Senha para entrar (vazio = sem senha) |
| `PAL_AdminPassword` | `""` | Senha de administrador (para RCON e comandos admin) |
| `PAL_ServerPlayerMaxNum` | `32` | Numero maximo de jogadores |
| `PAL_PublicPort` | `8211` | Porta do jogo |
| `PAL_RCONEnabled` | `False` | Habilitar RCON para administracao remota |
| `PAL_RCONPort` | `25575` | Porta do RCON (requer `RCONEnabled=True`) |
| `PAL_DayTimeSpeedRate` | `1.000000` | Velocidade do dia |
| `PAL_NightTimeSpeedRate` | `1.000000` | Velocidade da noite |
| `PAL_ExpRate` | `1.000000` | Multiplicador de experiencia |
| `PAL_PalCaptureRate` | `1.000000` | Taxa de captura de Pals |
| `PAL_DeathPenalty` | `All` | Penalidade de morte (`None`, `Item`, `ItemAndEquipment`, `All`) |

> Para a lista completa de configuracoes, consulte o arquivo `DefaultPalWorldSettings.ini` gerado pelo servidor ou a [documentacao oficial](https://docs.palworldgame.com/).

---

## Portas

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| `8211` | UDP | Porta principal do jogo (conexao dos jogadores) |
| `27015` | UDP | Steam query port (listagem de servidores) |
| `25575` | TCP | RCON (apenas se `PAL_RCONEnabled=True`) |

> Se habilitar RCON, adicione o mapeamento da porta 25575 no `docker-compose.yml`:
> ```yaml
> ports:
>   - "8211:8211/udp"
>   - "27015:27015/udp"
>   - "25575:25575/tcp"  # RCON
> ```

---

## Volumes e persistencia

| Volume | Caminho no container | Conteudo |
|--------|---------------------|----------|
| `palworld-data` | `/home/steam/palserver/Pal/Saved` | Saves, configs, logs do servidor |

Os dados do jogo persistem entre:
- Restarts do container (`docker compose restart`)
- Rebuilds (`docker compose up --build`)
- Redeploys no Coolify

Os dados **nao** persistem se voce remover o volume explicitamente:

```bash
# CUIDADO: isso apaga todos os saves!
docker volume rm palworld-data
```

---

## Backup dos saves

Os saves ficam dentro do volume Docker. Para fazer backup manual:

```bash
# Descobrir onde o volume esta no host
docker volume inspect palworld-data --format '{{ .Mountpoint }}'

# Copiar para um diretorio de backup
sudo cp -r $(docker volume inspect palworld-data --format '{{ .Mountpoint }}') ~/palworld-backup-$(date +%Y%m%d)
```

Para backup automatizado com cron:

```bash
crontab -e
```

Adicione (backup diario as 4h da manha):

```
0 4 * * * sudo cp -r $(docker volume inspect palworld-data --format '{{ .Mountpoint }}') /home/palworld/backups/palworld-$(date +\%Y\%m\%d-\%H\%M)
```

---

## Solucao de problemas

### Container reinicia em loop

Verifique os logs:

```bash
docker compose logs --tail 100
```

Causas comuns:
- **RAM insuficiente:** o servidor precisa de no minimo 8 GB livres
- **Disco cheio:** SteamCMD precisa de ~6 GB para o download + espaco para saves

### Servidor nao aparece na lista

- Verifique se `COMMUNITY_SERVER=true` esta definido
- Confirme que as portas UDP 8211 e 27015 estao abertas no firewall **e** no painel do provedor
- Aguarde alguns minutos apos o servidor iniciar (pode demorar para propagar)

### Jogadores nao conseguem conectar

- Verifique se a porta 8211/udp esta acessivel externamente:
  ```bash
  # De outra maquina
  nc -zuv IP_DA_VPS 8211
  ```
- Se estiver usando Coolify, confirme que o proxy esta **desabilitado** para este servico

### Erro de steamclient.so

Se aparecer `steamclient.so: cannot open shared object file`, o entrypoint ja trata isso com um symlink automatico. Se persistir, verifique os logs para erros no SteamCMD.

### Saves corrompidos / quero resetar

Para resetar o mundo mantendo as configs:

```bash
docker compose down

# Acessar o volume
cd $(sudo docker volume inspect palworld-data --format '{{ .Mountpoint }}')

# Remover apenas os saves (manter Config)
sudo rm -rf SaveGames/

docker compose up -d
```
