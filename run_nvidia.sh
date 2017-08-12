xhost +local:root
nvidia-docker run -it --env="DISPLAY" \
                      --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
                      --volume="/usr/lib/x86_64-linux-gnu/libXv.so.1:/usr/lib/x86_64-linux-gnu/libXv.so.1" \
                      -v "$PWD":/src \
                      -v bender_home:/home/bender \
                      yrahal/udacity-robond vglrun bash
xhost -local:root
