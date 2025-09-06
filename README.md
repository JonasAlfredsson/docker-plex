# docker-plex
Official [Plex Docker image][1] extended with the
[HTTP AniDB Metadata Agent (HAMA)][2] and [Absolute Series Scanner (ASS)][3]
plug-ins added, along with some slight modifications to how the `ENTRYPOINT`
and `CMD` is set up.

The images uploaded here also makes use of additional less specific tags which
moves when a new "specific" version is released:
- MAJOR -> `1`
- MAJOR.MINOR -> `1.42`
- MAJOR.MINOR.PATCH -> `1.42.1`
- "specific" -> `1.42.1.10060-4e8b05daf`

## Differences From the Official Image
The official image uses the [S6 process supervisor][4] as the `ENTRYPOINT` and
defines Plex as a "supervised service" inside the the `/etc/services.d` folder.
What this meas is that Docker (which already is a process supervisor) first
starts (and supervises) the S6 process supervisor which in turn then goes on to
start (and supervise) the Plex service, and to me this seems like a weird
design choice.

While I do understand that there might be usecases which benefits from having
an additional process supervisor baked in to the Docker image, I do not think it
provides any benefits here since Plex is the one and only process running inside
this container. I especially don't think it should be started as a "supervised
service", since I believe a failure of this program should bring down the
container, and the S6 documentation actually seems to agree with me there:

> By default, services created in /etc/services.d will automatically restart.
> If a service should bring the container down, you should probably run it as a
> CMD instead...

However, instead of basically rebuilding the entire image from scratch I took
the liberty of configuring S6 to behave more in line with the common "run
`/entrypoint.sh` that ends with `exec <target_program> $@`" pattern. This meant
setting the start of Plex directly as the `CMD`, and configuring so that the
container will fail to start in case any of the scripts inside `/cont-init.d/`
(the `/entrypoint.d/` equivalent in the S6 case) exit with an non-zero code
(which the official image ignores).

This, in my opinion, provides us with a much more sane Docker experience that
is more in line with how many of the largest Docker images behave, and makes
it easier to monitor for bad behavior.

Beyond that I have just added the [HAMA][2] and [ASS][3] plug-ins (including
their dependencies), along with a [`cont-init.d`](cont-init.d/20-symlink-folders)
script for moving them into the correct location during startup.


## Usage
The usage is basically identical to the official image, so go to its [README][1]
for those details.

However, I use this image is mainly used by my [Ansible role][5], so check that
one out if it is of interest.


## Useful Information
This section provides some extra information about how the Plex container
works, which I either couldn't find in the current documentation or it was
very unclear to me. Read at your own leisure.

### The `/config` Folder
The `/config` folder is set as the home directory of the `plex` user (i.e.
`echo ~plex`). The Plex program will then continue to create the following
folder structure: `/confg/Library/Application Support/Plex Media Server/`. This
path is what is assembled as `pmsBaseDir` in most of the `cont-init.d` scripts,
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
