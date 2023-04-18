# Docker commands

## Restore

- Download the backup file from the server and save it in the `db_dump` folder at the root of the project

- Connect to the database container
`docker-compose exec database bash`

- Create a backup folder on the database container
`mkdir app/db_dump`

- Exit the container
- Copy the backup file to the docker container
`docker-compose cp db_dump/kasaharacup_production.sql database:app/db_dump`

- Restore the backup file
`docker exec -it kasaharacup-database-1 pg_restore  -U postgres -d kasaharacup_development app/db_dump/kasaharacup_production.sql`
