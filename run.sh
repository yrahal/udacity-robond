#!/bin/bash

user=bender
image=yrahal/udacity-robond
ports=()
# RosCore 11311
default_ports=(5901 6080 8888 4000 4567)
volumes=()
default_volumes=("$PWD":"/src" "$user-home":"/home/$user")
gpu=0
jupyter=0
display=0
vgl=0
novnc=0
nomachine=0
chrome=0
privileged=0
default_ports_flag=1
default_volumes_flag=1
executable=docker
cmd=()
help=0
# Option to use the host's network
#--net=host

usage() {
  echo " Usage: `basename $0`:
  
  Run the docker container, given the provided options.

    -p|--ports=    Comma separated ports to map.
                   For example: -p 80,22,8080 will create three mappings for
                   each provided port.
                   You can also provide custom mappings such as: -p 8080:80.
    -v|--volumes=  Comma separated volume paths. If a single path is
                   provided, the mapping will bind the same path on both the
                   host and the container. Custom mappings can also be provided
                   (of the form \"host_path\":\"container_path\").
    -g|--gpu       Run the container with GPU/Nvidia bindings to expose the
                   host GPU to the container.
                   Requires nvidia-docker.
    -j|--jupyter   Start the container and run a Jupyter server.
    -d|--display   Set the container to display into the host.
    -h|-help       Print this message and exit.

    --novnc        Run a noVNC server along with TurboVNC to allow for browser
                   access. Needs port 6080 of the container to be mapped.
    --nomachine    Run a NoMachine server along with TurboVNC to allow for
                   audio and hardware access. Needs port 4000 of the container
                   to be mapped.
    --chrome       Running Chrome inside the container requires adding extra
                   capabilities to the container. This flag ensures they are
                   added.
    --privileged   Run the container in privileged mode.
    --no-def-ports Ignore default port mappings.
    --no-def-vols  Ignore default volume mappings.

    command and arguments to run in the container (optional).
    
    Note: If the gpu and display flags are both on, 'vglrun' will automatically
    be prepended to the command to execute if it's not empty.
  "
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p) tmp=$2; IFS=',' list=("${tmp[@]}"); ports+=($list); shift 2;;
    -v) tmp=$2; IFS=',' list=("${tmp[@]}"); volumes+=($list); shift 2;;
    -g) gpu=1; shift 1;;
    -j) jupyter=1; shift 1;;
    -d) display=1; shift 1;;
    -h) usage; exit 1;;
    
    --ports=*) tmp="${1#*=}"; IFS=',' list=("${tmp[@]}"); ports+=($list); shift 1;;
    --volumes=*) tmp="${1#*=}"; IFS=',' list=("${tmp[@]}"); volumes+=($list); shift 1;;
    --gpu) gpu=1; shift 1;;
    --jupyter) jupyter=1; shift 1;;
    --display) display=1; shift 1;;
    --novnc) novnc=1; shift 1;;
    --nomachine) nomachine=1; shift 1;;
    --chrome) chrome=1; shift 1;;
    --privileged) privileged=1; shift 1;;
    --no-def-ports) default_ports_flag=0; shift 1;;
    --no-def-vols) default_volumes_flag=0; shift 1;;
    --help) usage; exit 1;;

    --ports|--volumes) echo "$1 requires an argument" >&2; exit 1;;

    -*) echo "unknown option: $1" >&2; exit 1;;
    *) cmd+=($1); shift 1;;
  esac
done

# Add a mapping and change the executable if the --gpu option is set
if [ $gpu -eq 1 ] ; then
  volumes+=("/usr/lib/x86_64-linux-gnu/libXv.so.1")
  executable=nvidia-docker
fi

# Set jupyter to launch within the proper environment if the --jupyter option is set
if [ $jupyter -eq 1 ] ; then
  cmd=(bash -c "source /opt/utils/bin/conda-add && jupyter-server-run")
fi

# Add a mapping if the --display option is set
if [ $display -eq 1 ] ; then
  volumes+=("/tmp/.X11-unix")
fi

# If both --display and --gpu are set, then set the vgl option
if [ $gpu -eq 1 -a $display -eq 1 -a ${#cmd[@]} -gt 0 ] ; then
  vgl=1
fi

# If the vgl option is set, then prepend the commands with 'vglrun'
if [ $vgl -eq 1 ] ; then
  cmd=(vglrun "${cmd[@]}")
fi

# Add the default ports if the default_ports_flag is set (default)
if [ $default_ports_flag -eq 1 ] ; then
  ports=("${default_ports[@]}" "${ports[@]}")
fi

# Add the default volumes if the default_volumes_flag is set (default)
if [ $default_volumes_flag -eq 1 ] ; then
  volumes=("${default_volumes[@]}" "${volumes[@]}")
fi

# Start building the command to run
command_to_run=($executable run -it --rm)

# Add the display if the --display option is set
if [ $display -eq 1 ] ; then
  command_to_run+=(--env="DISPLAY")
fi

# Add the ports
for item in "${ports[@]}"; do
  if grep -q ":" <<< ${item} ; then
     command_to_run+=(-p ${item})
  else
     command_to_run+=(-p ${item}:${item})
  fi
done

# Add the volumes
for item in "${volumes[@]}"; do
  if grep -q ":" <<< ${item} ; then
    command_to_run+=(-v ${item})
  else
    command_to_run+=(-v ${item}:${item})
  fi
done

# Set the $LAUNCH_NOVNC variable on the container in order to start the noVNC server
if [ $novnc -eq 1 ] ; then
  command_to_run+=(-e LAUNCH_NOVNC=1)
fi

# Add capabilities to enable the NoMachine server and set the LAUNCH_NOMACHINE variable
if [ $nomachine -eq 1 ] ; then
  command_to_run+=(-e LAUNCH_NOMACHINE=1 --device /dev/fuse --cap-add SYS_ADMIN --cap-add=SYS_PTRACE)
fi

# Add capabilities to allow proper execution of Chrome
if [ $chrome -eq 1 ] ; then
  command_to_run+=(--cap-add=SYS_ADMIN)
fi

# Add privileged if needed
if [ $privileged -eq 1 ] ; then
  command_to_run+=(--privileged)
fi

# Add the image and the target to run
command_to_run+=($image "${cmd[@]}")

echo Running:
echo "${command_to_run[@]}"

# If --display is set, allow the non-network local connections
if [ $display -eq 1 ] ; then
  xhost +local:root
fi

# Create and run the container
"${command_to_run[@]}"

# If --display is set, reset the access control list
if [ $display -eq 1 ] ; then
  xhost -local:root
fi
