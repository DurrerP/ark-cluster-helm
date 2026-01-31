


docker buildx build . -t ghcr.io/durrerp/ark-cluster-helm:latest --no-cache

docker buildx build . -t ghcr.io/durrerp/ark-cluster-helm:latest -t ghcr.io/durrerp/ark-cluster-helm:v0.0.1

docker push ghcr.io/durrerp/ark-cluster-helm:latest
docker push ghcr.io/durrerp/ark-cluster-helm:v0.0.1


docker run -p 7777:7777 -p 7778:7778 -p 27015:27015 -it ghcr.io/durrerp/ark-cluster-helm:latest

docker run -it -p 7777:7777/tcp -p 7777:7777/udp -p 7778:7778/tcp -p 7778:7778/udp -p 27015:27015/tcp -p 27015:27015/udp ghcr.io/durrerp/ark-cluster-helm:latest
