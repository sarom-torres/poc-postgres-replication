docker run -d \
--network dockernetwork --ip 172.18.0.105 -p 5455:5432 \
--name primary-sec -h primary-sec \
-e "POSTGRES_DB=postgres" \
-e "POSTGRES_USER=postgres" \
-e "POSTGRES_PASSWORD=postgres" \
-v $(pwd)/data/psql/primary:/var/lib/postgresql/data \
-v $(pwd)/certs:/etc/ssl/certs \
postgres:14.2-bullseye
