xhost +local:root
nvidia-docker run -it --rm --env="DISPLAY" \
                      -v "/tmp/.X11-unix":"/tmp/.X11-unix" \
                      -v "/usr/lib/x86_64-linux-gnu/libXv.so.1":"/usr/lib/x86_64-linux-gnu/libXv.so.1" \
                      -v "$PWD":"/src" \
                      -v "bender-home":"/home/bender" \
                      yrahal/udacity-robond vglrun bash
xhost -local:root
