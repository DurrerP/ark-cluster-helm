


docker buildx build . -t ghcr.io/durrerp/ark-cluster-helm:latest

docker buildx build . -t ghcr.io/durrerp/ark-cluster-helm:latest -t ghcr.io/durrerp/ark-cluster-helm:v0.0.1


docker run -p 7777:7777 -p 27010:27010 -it ghcr.io/durrerp/ark-cluster-helm:latest