docker run -it \
    -e DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /tmp/docker-occ:/tmp/docker-occ \
    --user="$(id --user):$(id --group)" \
    mon-centos7