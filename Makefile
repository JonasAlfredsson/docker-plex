all: build

build:
	docker build --progress=plain -t jonasal/plex:local .

run:
	docker run -it --rm \
	--network=host \
	--name=plex \
	-e PLEX_UID='$(shell id -u)' \
	-e PLEX_GID='$(shell id -g)' \
	-v $(PWD)/tmp/config:/config \
	-v $(PWD)/tmp/transcode:/transcode \
	-v $(PWD)/tmp/data:/data:ro \
	jonasal/plex:local

dev:
	docker buildx build --platform linux/amd64,linux/386,linux/arm64,linux/arm/v7 --tag jonasal/plex:dev .

push-dev:
	docker buildx build --platform linux/amd64,linux/386,linux/arm64,linux/arm/v7 --tag jonasal/plex:dev --pull --push .
