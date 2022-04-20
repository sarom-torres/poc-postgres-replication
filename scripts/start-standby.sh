docker run -d \
--network dockernetwork --ip 172.18.0.106 -p 5456:5432 \
--name standby-sec -h standby-sec \
-e "POSTGRES_DB=postgres" \
-e "POSTGRES_USER=postgres" \
-e "POSTGRES_PASSWORD=postgres" \
-v $(pwd)/certs:/etc/ssl/certs \
-v $(pwd)/data/psql/standby:/var/lib/postgresql/data \
postgres:14.2-bullseye
#-v $(pwd)/data/psql/repl:/var/lib/postgresql/repl \
#-v $(pwd)/data/psql/standby:/var/lib/postgresql/data \
