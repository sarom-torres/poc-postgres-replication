# Configuração de replicação PostgreSQL

<img src="https://user-images.githubusercontent.com/34520860/164287623-f6cf87db-2a5e-4a1a-bb6a-c2bf46e53fb9.png" width="350">


## Execução da POC de replicação
> É necessário ter o Docker e o Docker Compose instalado

1. Criar uma rede para conectar os contêineres
    ```
    docker network create --subnet=172.18.0.0/24 dockernetwork
    ```
2. Mudar permissões de diretórios de volumes
    ```
    chown 999:999 data/psql/primary data/psql/standby certs
    chmod 600 certs/server.key
    ```
3. Executar o ambiente utlizando docker compose
   ```
   docker-compose up -d primary
   docker-compose up -d standby
   ```
----------------------------------------------

# Construção do ambiente de replicação

## Primary

1. Criar uma rede para conectar os contêineres
    ```
    docker network create --subnet=172.18.0.0/24 dockernetwork
    ```
2. Listar as redes disponíveis
    ```
    docker network ls
    ```
3. Criar diretórios de volumes dos conteiners
    ```
    mkdir -p /data/psql/primary
    mkdir -p /data/psql/standby
    mkdir -p /data/psql/repl
    chown 999:999 data/psql/primary data/psql/standby data/psql/repl
    ```
4. Criar certificados e volume para armazená-los
    ```
    mkdir certs
    cd certs
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr
    openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
    ``` 
5. Criar arquivo para inicializar o primário `start-prim.sh`  e mudar permissões (`chmod 775 start-prim.sh `) para execução do arquivo.
    ```
    docker run -d \
    --network dockernetwork --ip 172.18.0.105 -p 5455:5432 \
    --name primary-sec -h primary-sec \
    -e "POSTGRES_DB=postgres" \
    -e "POSTGRES_USER=postgres" \
    -e "POSTGRES_PASSWORD=postgres" \
    -v $(pwd)/data/psql/primary:/var/lib/postgresql/data \
    -v $(pwd)/certs:/etc/ssl/certs \
    postgres:14.2-bullseye
    ```
5. Executar a imagem docker e verificar seu funcionamento
    ```
    docker ps -a -f network=dockernetwork --format "table {{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Networks}}\t{{.Ports}}"
    ```
6. Criar uma conta de usuário especial para primary-standby stream replication.
    
    1. entrar no conteiner
        ```
        docker exec -it primary bash
        ```
    2. conectar ao postgres
        ```
        psql -U postgres
        ```
    3. criar usuário para replicação
        ```
        # Username repuser; Número máximo de links: 10; Senha: 123456
        CREATE ROLE repuser WITH LOGIN REPLICATION CONNECTION LIMIT 10 PASSWORD '123456';
        ```
        > `CREATE ROLE xxx WITH LOGIN REPLICATION` determina se um _role_ é do tipo replicação. Um _role_ deve ter esse atributo para poder se conectar ao servidor no modo de replicação e para poder criar ou descartar slots de replicação.
    4. ver roles
        ```
        \du
        ```
7. Mudando as configurações do primário
    ```
    # 1. Entrar no diretório do primário
    cd /data/psql/primary
    # 2. Adicionar as regras ao final
    echo "host replication repuser 172.18.0.102/24 md5" >> pg_hba.conf
    ```
8. Editar o arquivo `postgres.conf`
    ```
    # aceitar apenas requisicoes do localhost e da replica 
    listen_addresses = '0.0.0.0, localhost, 172.18.0.106'
    
    # usar criptografia scram-sha-256 para hash das senhas
    password_encryption = scram-sha-256

    # configurar conexao SSL no servidor
    ssl = on
    ssl_cert_file = '/etc/ssl/certs/server.crt'
    ssl_key_file = '/etc/ssl/certs/server.key'

    # criar backup de todas as transações
    archive_mode = on				
    archive_command = '/bin/date'	

    # numero de conexões concorrentes vinda da replica que o primario pode atender
    max_wal_senders = 10	
		
    # Especifica tamanho minimo de segmentos que devem ser retidos no diretório pg_wal para replicacao	
    wal_keep_size = 16		
    ```
    
    > Ver qual comando é executado ao fazer o backup das transações: `SELECT name,setting FROM pg_settings WHERE name LIKE 'archive%';`
    > Ver ultimo backup feito: `SELECT * FROM pg_stat_archiver;` ou `SELECT archived_count,last_archived_wal,last_archived_time FROM pg_stat_archiver;`
9. Reiniciar o conteiner primario
    ```
        #Using pg_ctl stop stops the database safely
        docker exec -it -u postgres primary pg_ctl stop
        docker start primary
    ```

## Standby

1. Executar o conteiner standby
    ```
    docker run -d \
    --network dockernetwork --ip 172.18.0.102 -p 5444:5433 \
    --name standby -h standby \
    -e "POSTGRES_DB=postgres" \
    -e "POSTGRES_USER=postgres" \
    -e "POSTGRES_PASSWORD=postgres" \
    -v $(pwd)/data/psql/standby:/var/lib/postgresql/data \
    -v $(pwd)/data/psql/repl:/var/lib/postgresql/repl \
    postgres
    ```
2. Entrar no conteiner `standby`
    ```
    docker exec -it -u postgres standby /bin/bash
    ```
3. Fazer backup dados
    ```
    pg_basebackup -R -D /var/lib/postgresql/repl -Fp -Xs -v -P -h 172.18.0.105 -p 5432 -U repuser
    ```
### Criar o standby a partir do backup 

Após o backup dos dados, é possível reconstruir o container `stadnby` usando os dados em `data/psql/repl`. 

1. Deletar o container
    ```
    docker rm -f slave
    ```
2. Deletar o diretório original do `data/psql/standby` e renomear o diretório `data/psql/repl` contendo o backup para `data/psql/standby`:
    ```
    cd /data/psql/
    rm -rf slave
    mv repl slave
    cd /data/psql/slave
    ```
3. Verificar informação da configuração (`cat postgresql.auto.conf`) no arquivo `postgresql.auto.conf` que deverá conter a seguinte informação sobre o primário:
    ```
    primary_conninfo = 'user=repuser password=123456 channel_binding=prefer host=172.18.0.101 port=5432 sslmode=prefer sslcompression=0 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any'
    ```
4. Reconstruir o standby a partir das novas configurações
    ```
	docker run -d \
	--network dockernetwork --ip 172.18.0.106 -p 5456:5432 \
	--name standby-sec -h standby-sec \
	-e "POSTGRES_DB=postgres" \
	-e "POSTGRES_USER=postgres" \
	-e "POSTGRES_PASSWORD=postgres" \
	-v $(pwd)/certs:/etc/ssl/certs \
	-v $(pwd)/data/psql/standby:/var/lib/postgresql/data \
	postgres:14.2-bullseye
    ```
5. Ver as informações de replicação das bases
    ```
    ps -aux | grep postgres
    ```

--------------------------------------------------------------------------------------
# Testes

## Testar replicação aasíncrona quando o standby está down

> A replicação **assíncrona** é realizada por default no mod streaming, para que ela seja síncrona a diretiva `synchronous_standby_names` no arquivo `/var/lib/postgresql/data/postgresql.conf` deve ser configurada.

1. Criar base e tabela para testes:
   ```
   CREATE DATABASE testedb;
   CREATE TABLE teste ("id" SERIAL PRIMARY KEY, "value" varchar(255));
   INSERT INTO teste(value) VALUES('teste-DB');
   SELECT * FROM teste;
   ```
 ## Testar conexão SSL

```
SELECT * FROM pg_stat_ssl;
```

--------------------------------------------------------------------------------------
# Principais arquivos de configuração para replicação

## Arquivo pg_hba.conf

### Formato
```
# host      database     user     address          auth-method 
  hostssl   replication  repuser  172.18.0.102/24  scram-sha-256
```

### Notas
- Habilitar a autenticação entre o servidor PostgreSQL e o aplicativo cliente. 
- Consiste em uma série de entradas que definem um `host` e suas permissões associadas (ex. o banco de dados ao qual ele pode se conectar, o método de autenticação a ser usado, etc).
- Quando o cliente solicita uma conexão esta deve especificar um **nome de usuário do PostgreSQL** e um **db** com o qual pretende se conectar. Opcionalmente, uma senha pode ser fornecida, dependendo da configuração esperada para o host de conexão.
- Quando o PostgreSQL recebe uma solicitação de conexão, ele verifica o arquivo `pg_hba.conf` para verificar se a máquina da qual o aplicativo está solicitando uma conexão tem direitos para se conectar ao banco de dados especificado. Se a máquina que está solicitando o acesso tiver permissão para se conectar, o PostgreSQL verificará as condições que a aplicação deve atender para se autenticar com sucesso.
- O PostgreSQL verificará o método de autenticação via `pg_hba.conf` para **cada solicitação de conexão**. Essa verificação é realizada sempre que uma nova conexão é solicitada do servidor PostgreSQL, portanto, **não há necessidade de reiniciar** o PostgreSQL após adicionar, modificar ou remover uma entrada no arquivo pg_hba.conf
