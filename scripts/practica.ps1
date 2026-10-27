[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $repoRoot 'evidencias'
$transcriptPath = Join-Path $evidenceDirectory '01-ejecucion-practica.txt'
$postgresImage = 'postgres:17'
$labPassword = 'PgLab_2026!'

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Wait-Postgres {
    param([string]$ContainerName)

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        docker exec $ContainerName pg_isready -U postgres | Out-Host
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 2
    }
    throw "PostgreSQL no estuvo disponible en $ContainerName después de 60 segundos."
}

function Assert-DockerResourceAbsent {
    param(
        [ValidateSet('container', 'volume')]
        [string]$Type,
        [string]$Name
    )

    if ($Type -eq 'container') {
        $match = docker container ls -a --filter "name=^/$Name$" --format '{{.Names}}'
    } else {
        $match = docker volume ls --filter "name=^$Name$" --format '{{.Name}}'
    }

    if ($match -eq $Name) {
        throw "Ya existe el recurso $Type '$Name'. Se detuvo la práctica para proteger datos existentes. Revíselo y use otro entorno limpio."
    }
}

New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
Start-Transcript -Path $transcriptPath -Force -UseMinimalHeader

try {
    Write-Step 'Verificación de Docker'
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'No se encontró el comando docker. Instale Docker Desktop y vuelva a ejecutar el script.'
    }
    docker version
    if ($LASTEXITCODE -ne 0) {
        throw 'El cliente Docker existe, pero el motor no responde. Inicie Docker Desktop.'
    }

    Assert-DockerResourceAbsent -Type container -Name 'server_db1'
    Assert-DockerResourceAbsent -Type container -Name 'server_db2'
    Assert-DockerResourceAbsent -Type volume -Name 'pgdata'

    Write-Step 'Parte 1: creación de server_db1 sin volumen nombrado'
    docker run --name server_db1 --detach --env "POSTGRES_PASSWORD=$labPassword" --publish 5432:5432 $postgresImage
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear server_db1.' }
    Wait-Postgres -ContainerName 'server_db1'

    Write-Step 'Creación de la base test, tabla customer y registros'
    docker exec server_db1 psql -U postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE test;'
    Get-Content (Join-Path $repoRoot 'sql\customer.sql') -Raw | docker exec -i server_db1 psql -U postgres -d test -v ON_ERROR_STOP=1
    docker exec server_db1 psql -U postgres -d test -c 'TABLE customer;'

    Write-Step 'Eliminación de server_db1 y de su volumen anónimo asociado'
    docker stop server_db1
    docker rm --volumes server_db1

    Write-Step 'Recreación de server_db1 sin reutilizar almacenamiento'
    docker run --name server_db1 --detach --env "POSTGRES_PASSWORD=$labPassword" --publish 5432:5432 $postgresImage
    Wait-Postgres -ContainerName 'server_db1'
    $databaseFound = docker exec server_db1 psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datname = 'test';"
    if ($LASTEXITCODE -ne 0) { throw 'Falló la comprobación de la base test en server_db1.' }
    if ($databaseFound -match '\S') {
        throw 'Resultado inesperado: la base test existe en el server_db1 recreado.'
    }
    Write-Host 'COMPROBADO: la base de datos test no existe en el contenedor recreado.' -ForegroundColor Green

    Write-Step 'Liberación del puerto 5432 para la Parte 2'
    docker stop server_db1

    Write-Step 'Parte 2: creación del volumen pgdata y server_db2'
    docker volume create pgdata
    docker run --name server_db2 --detach --env "POSTGRES_PASSWORD=$labPassword" --publish 5432:5432 --mount type=volume,source=pgdata,target=/var/lib/postgresql/data $postgresImage
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear server_db2.' }
    Wait-Postgres -ContainerName 'server_db2'

    Write-Step 'Creación de la base test, tabla customer y registros en pgdata'
    docker exec server_db2 psql -U postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE test;'
    Get-Content (Join-Path $repoRoot 'sql\customer.sql') -Raw | docker exec -i server_db2 psql -U postgres -d test -v ON_ERROR_STOP=1
    docker exec server_db2 psql -U postgres -d test -c 'TABLE customer;'

    Write-Step 'Eliminación de server_db2 sin eliminar pgdata'
    docker stop server_db2
    docker rm server_db2
    docker volume inspect pgdata

    Write-Step 'Recreación de server_db2 con el mismo volumen'
    docker run --name server_db2 --detach --env "POSTGRES_PASSWORD=$labPassword" --publish 5432:5432 --mount type=volume,source=pgdata,target=/var/lib/postgresql/data $postgresImage
    Wait-Postgres -ContainerName 'server_db2'

    Write-Step 'Comprobación de persistencia'
    $databaseFound = docker exec server_db2 psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datname = 'test';"
    if ($databaseFound -notmatch '^test$') {
        throw 'La base test no apareció después de montar nuevamente pgdata.'
    }
    docker exec server_db2 psql -U postgres -d test -c 'TABLE customer;'
    $rowCount = docker exec server_db2 psql -U postgres -d test -tAc 'SELECT COUNT(*) FROM customer;'
    if ($rowCount -notmatch '^2$') {
        throw "Se esperaban 2 registros persistidos y se obtuvo: $rowCount."
    }
    Write-Host 'COMPROBADO: test, customer y sus 2 registros persistieron en pgdata.' -ForegroundColor Green

    Write-Step 'Estado final'
    docker ps -a --filter 'name=server_db1' --filter 'name=server_db2'
    docker volume ls --filter 'name=pgdata'
    Write-Host 'La práctica terminó correctamente. server_db1 quedó detenido; server_db2 está en ejecución; pgdata se conserva.' -ForegroundColor Green
}
finally {
    Stop-Transcript
}

