# PostgreSQL Replication

Algumas soluções lidam com a sincronização permitindo que apenas um servidor modifique os dados. 

- Os servidores que podem modificar dados são chamados de servidores `read/write`, `master` ou `primary`. 
- Os servidores que rastreiam as alterações no primário são chamados de servidores `standby` ou `secondary`. 
- `warm standby`: servidor `standby` que **não** pode ser conectado até que seja promovido a servidor primário 
- `hot standby`: servidor que pode aceitar conexões e atende a consultas somente leitura. (a partir da **versão 9.0**).

## Síncrono vs assíncrono

- `soluções síncronas`: uma transação de modificação de dados não é considerada confirmada até que todos os servidores tenham confirmado a transação. Isso garante que um failover não perderá nenhum dado e que todos os servidores com balanceamento de carga retornarão resultados consistentes, independentemente do servidor consultado. 
- `soluções assíncronas`: permitem algum atraso entre o momento de uma confirmação e sua propagação para os outros servidores, abrindo a possibilidade de que algumas transações possam ser perdidas na mudança para um servidor de backup e que os servidores com balanceamento de carga possam retornar resultados ligeiramente obsoletos. A comunicação assíncrona é usada quando a síncrona seria muito lenta.

## Granularidade

Algumas soluções podem lidar apenas com um servidor de banco de dados inteiro, enquanto outras permitem o controle por tabela ou por banco de dados.


## WAL - Write-Ahead Log

- _Write-Ahead Log_ (WAL), no PostgreSQL, também é conhecido como log de transações. Um log é um registro de todos os eventos ou alterações e os dados WAL são apenas uma descrição das alterações feitas nos dados reais. Então, são _dados sobre dados_ ou metadados. 

- Implica que qualquer alteração feita no banco de dados deve primeiro ser anexada ao arquivo de log e, em seguida, o arquivo de log deve ser liberado para o disco

- `pg_wal`: diretório usado para armazenar arquivos WAL no PostgreSQL 10. 
- `pg_xlog`: diretório usado para armazenar arquivos WAL nas versões anterioes ao PostgreSQL 10. 

- É recomendado armazenar os arquivos Postgres WAL em um disco físico diferente montado no sistema de arquivos do seu servidor.

### Log Sequence Number (LSN)

- À medida que novos registros são gravados, eles são anexados aos logs do WAL. 
- O _Log Sequence Number_ (LSN) é um identificador exclusivo no log de transações. Ele representa uma posição de um registro no fluxo WAL. Ou seja, à medida que os registros são adicionados ao log do Postgres WAL, suas posições de inserção são descritas pelo número de sequência do log. 
- **pg_lsn** é o tipo de dados no qual um número de sequência de log é retornado.

### Commit síncrono vs assíncrono

- **Commit síncrono**: não é possível continuar o trabalho até que todos os arquivos WAL sejam armazenados no disco. 
  - Nesse modo é possivel obter **900 transações por segundo**.
- **Commit assíncrono**: permite a conclusão mais rápida da transação ao custo de perda de dados. Ele retorna com sucesso assim que a transação é completada logicamente, mesmo antes que o WAL a registre, eles vão para o disco. 
  - Nesse modo é possível obter **1.500 transações por segundo**.

-------------------------------------------------------------------------

# Replicação Postgres WAL

A preplicação WALpode ocorrer de duas maneiras entre os servidores de banco de dados:

## File-Based Log Shipping

- o primary envia diretamente os logs WAL para o standby. 
- o primary pode copiar os logs para o armazenamento dos servidores standby ou simplesmente compartilhar o armazenamento com eles.
- todos os logs WAL têm uma capacidade máxima de armazenamento de 16 MB.
- os logs WAL **são enviados para o standby somente após atingirem o valor limite**. Isso pode causar um atraso no processo de replicação e aumentar as chances de perda de dados devido a uma possível falha do primary.

<img src="https://user-images.githubusercontent.com/34520860/162759413-8a4b6608-07c7-4ebb-b919-322b37ee0dca.png" width="350">

## Streaming WAL Records

- os servidores standby estabelecem uma conexão com o servidor primary e recebem os fragmentos WAL (chunks). 
- a vantagem do streaming de registros WAL é que ele não espera que a capacidade esteja cheia, eles são transmitidos imediatamente. Isso ajuda a manter o servidor em espera atualizado.
- a replicação de streaming é assíncrona por padrão, mas também pode ser configurada no modo de replicação síncrona.
- a replicação de streaming usa um usuário de replicação para operações de replicação

<img src="https://user-images.githubusercontent.com/34520860/162760804-5e1fd63b-f0ce-43fd-8db8-21542aabd70e.png" width="350">
