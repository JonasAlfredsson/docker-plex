all: build

build:
	docker build --progress=plain -t jonasal/plex:local .

run:
	docker run -it --rm \
	--network=host \
	--name=plex \
	jonasal/plex:local

dev:
	docker buildx build --platform linux/amd64,linux/386,linux/arm64,linux/arm/v7 --tag jonasal/plex:dev .
