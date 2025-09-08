# docker-plex
A rewrite of the official [Plex Docker image][1] based on `debian-slim`
instead of `ubuntu`, and with Plex running as PID 1 instead of under the
[S6 process supervisor][4] which allows for a more sane startup and exit of the
container. Unless you ran the original container with auto-upgrading to the
BETA release channel this should be a drop-in replacement.

> Jump to [this section](#differences-from-the-official-image) to read about
> how this image differs in special cases.

We also produce an "extras" version of this image, with the
[HTTP AniDB Metadata Agent (HAMA)][2] and [Absolute Series Scanner (ASS)][3]
plug-ins added.

The image tagging strategy here also makes use of additional less specific tags
which move when a new "specific" version is released:
- MAJOR -> `1`
- MAJOR.MINOR -> `1.42`
- MAJOR.MINOR.PATCH -> `1.42.1`
- "specific" -> `1.42.1.10060-4e8b05daf`

Just append `-extras` to any of the tags above to get the image with the extras
in it.

> This image is mainly used by my [Ansible role][5], so check it out if that
> is of interest.

## Usage
The usage is basically identical to the official image, so go to its [README][1]
to get the basic details on which folders it writes to, and what environmental
variables are available.

However, after experimenting a lot with Plex it seems like there are times when
it takes longer than the [5 seconds][7] grace period they offer before going
in for the kill, so I would suggest starting the container with a more generous
[stop timeout][10]. This is just a small modification of the original
[example][9]:

```bash
# Here we change the timeout ↓
docker run -d --stop-timeout 60 \
    --name plex \
    --network=host \
    -e TZ="<timezone>" \
    -e PLEX_CLAIM="<claimToken>" \
    -v <path/to/plex/database>:/config \
    -v <path/to/transcode/temp>:/transcode \
    -v <path/to/media>:/data:ro \
    jonasal/plex:1.42.1-extras
# Here is this image ↑
```


## Differences From the Official Image
> TL;DR - Unless you explicitly jumped inside the official Plex container to
> restart the Plex service without the container going down, or were running
> the BETA release track, this image will behave better™ than the official one.

The official image uses the [S6 process supervisor][4] as the `ENTRYPOINT` and
defines Plex as a "supervised service" inside the the `/etc/services.d` folder.
What this means is that Docker (which already is a process supervisor) first
starts (and supervises) the S6 process supervisor which in turn then goes on to
start (and supervise) the Plex service, and to me this seems like a weird
design choice.

While I do understand that there might be some exotic usecases that benefits
from having an additional process supervisor baked in to the Docker image, I do
not think it provides any benefits here since Plex is the one and only process
running inside this container. I especially don't think it should be started
as a "supervised service", since I believe a failure of this program should
bring down the container.

However, after experimenting a lot with different settings, in order to have S6
behave more in line with the common "run `/entrypoint.sh` that ends with
`exec <target_program> $@`" pattern, I gave up. The container behaved
differently depending on if we stopped it through `ctrl+C` or via `docker stop`,
and the exit codes also didn't line up. The fact that S6 also have its own
"grace timeout before kill" that runs in parallel with the Plex [shutdown][7]
script AND the overarching (and all powerful) [`docker stop` timeout][8] made
it impossible to have Plex exit gracefully unless it did it in less than 5
seconds.

So I decided to rewrite the image to not use S6, and moved the S6
`/etc/cont-init.d/` folder to `/entrypoint.d/` and made any failures of these
startup scripts exit the container with a non-zero code (which the official
image ignores). Having Plex run as PID 1 also allows us to just increase the
`docker stop` timeout to allow for a much more graceful shutdown that doesn't
leave us with ghost PID files.

This, in my opinion, provides us with a much more sane Docker experience that
is more in line with how many of the largest Docker images behave, and makes
it easier to monitor for bad behavior.

We still keep the same environmental variables as the original image, and
beyond changing from `ubuntu` to `debian` we keep most of the same dependencies
installed that are used by the same startup scripts. However, the BETA
release track [updater/installer][6] is dropped since stopping the Plex service
(which is PID 1) now brings down the container, so it is not really possible
to do a "running reload" of it. This is by design, since I find it very weird
starting a container with a specific Docker tag to then have it run something
completely different inside.

Finally, something that _could_ be a reason for having a supervisor as PID 1
is that it has proper zombie reaping abilities. However, I did not see any
rouge processes during my testing. If you want to be overly safe you can just
start the container with `--init` to put the built in [tini][11] process in
front, but it shouldn't be necessary.

```bash
docker run --it --init jonasal/plex:1.42.1-extras
```

### The "extras" Image
The "extras" added are currently just the [HAMA][2] and [ASS][3] plug-ins
(including their dependencies), along with the
[`20-symlink-folders.sh`](./entrypoint.d/20-symlink-folders.sh) entrypoint
script for moving them into the correct location during startup.

This is just because I use these plug-ins and want them up to date with
the image running. To achieve this it adds symlinks inside the "live"
`/config` folder pointing back to the real files that are "inside" the running
container. What this means is that looking at these files outside of the
running container it will just look like broken links, but they do work inside.


## Useful Information
This section provides some extra information about how the Plex container
works, which I either couldn't find in the current documentation or it was
very unclear to me. Read at your own leisure.

### The `/config` Folder
The `/config` folder is set as the home directory of the `plex` user (i.e.
`echo ~plex`). The Plex program will then continue to create the following
folder structure: `/confg/Library/Application Support/Plex Media Server/`. This
path is what is assembled as `pmsBaseDir` in most of the `entrypoint.d` scripts,
and is the folder where all important files will be located.

### The `/transcode` Folder
The `/transcode` folder will be populated with the following path:
`/transcode/Transcode/Sessions/`. This holds the data of any media file that
needed to be transcoded to a different format for a particular client. This
data is transient and not really important, but can be stored for a longer time
as a cache so Plex don't have to re-encode the same file over and over.

### The `/data` Folder
This is just a suggested folder where you can mount your media library to. This
should probably only be mounted as read-only since Plex have no reason to write
anything under this path. However, it is possible to mount your library to any
path you want inside the container, just make sure the config points to
the correct location.






[1]: https://github.com/plexinc/pms-docker
[2]: https://github.com/ZeroQI/Hama.bundle
[3]: https://github.com/ZeroQI/Absolute-Series-Scanner
[4]: https://github.com/just-containers/s6-overlay
[5]: https://github.com/JonasAlfredsson/ansible-role-plex
[6]: https://github.com/plexinc/pms-docker/blob/master/root/etc/cont-init.d/50-plex-update
[7]: https://github.com/plexinc/pms-docker/blob/master/root/etc/services.d/plex/finish
[8]: https://docs.docker.com/reference/cli/docker/container/stop/#timeout
[9]: https://github.com/plexinc/pms-docker?tab=readme-ov-file#host-networking
[10]: https://docs.docker.com/reference/cli/docker/container/run/#stop-timeout
[11]: https://github.com/krallin/tini
