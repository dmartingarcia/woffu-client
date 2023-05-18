VERSION=0.4

docker build -t dmartingarcia0/woffu-client:$VERSION-alpine -t dmartingarcia0/woffu-client:latest .
docker push dmartingarcia0/woffu-client:latest && docker push dmartingarcia0/woffu-client:$VERSION-alpine
