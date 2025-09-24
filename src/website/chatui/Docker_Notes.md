# Docker Sample Commands

## Build and Push Docker Image

Configure the appsettings variables by copying appsettings.Template.json to appsettings.Development.json and update those values

## Build the app locally

``` bash
cd src/website/chatui/
docker build -t aichat -f Dockerfile . -t 091501
```

## Run the app

The docker run command creates and runs the container as a single command. This command eliminates the need to run docker create and then docker start. You can also set this command to automatically delete the container when the container stops by adding --rm

``` bash
docker run --rm -it -p 8000:8080 aichat 091501
curl http://localhost:8000
```

## Run with a parameter

``` bash
docker run -it --rm aichat AzureStorageAccountEndpoint="https://xxxxxx.blob.core.windows.net/"
```

## Inspect the container

``` bash
docker inspect aichat
```

## View list of images

``` bash
docker images 
```

## View current usage

``` bash
docker stats
```

## Create a new container (that is stopped)

``` bash
docker create --name aichat-container aichat
```

## To see a list of all containers

``` bash
docker ps -a
```

## Connect to a running container to see the output and peek at the output stream

``` bash
docker attach --sig-proxy=false aichat-container
```

## Start the container and show only containers that are running

``` bash
docker start aichat-container
docker ps
```

## Stop the container

``` bash
docker stop aichat-container
```

## Delete the container and check for existence

``` bash
docker ps -a
docker rm aichat-container
docker ps -a
```

## Delete images you no longer want

 You can delete any images that you no longer want on your machine.  Delete the image created by your Dockerfile and then delete the .NET image the Dockerfile was based on. You can use the IMAGE ID or the REPOSITORY:TAG formatted string.

``` bash
  docker rmi aichat:latest
  docker rmi mcr.microsoft.com/dotnet/aspnet:8.0
```

## Interactive shell

docker run -it --entrypoint /bin/sh  -p 8080:8080 -p 8081:8081 -p 32771:32771 "${image_name}.dev"

## Start service in container

``` bash
$ dotnet chatui.dll
curl -X POST -v http://localhost:8080/api/chat/weather \
     -H "X-Api-key: $DOTNET_APP_API_KEY" \
     -H "Content-Type: application/json" \
     -d '[{ "user": "What is the forecast for Mankato MN" }]'
```
