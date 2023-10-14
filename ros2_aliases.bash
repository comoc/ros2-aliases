#!/bin/bash

# MIT License

# Copyright (c) 2023 Shunsuke Kimura

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

export ROS2_ALIASES=$BASH_SOURCE
export ROS_DISTRO=humble

function red  { echo -e "\033[31m$1\033[m"; }
function green { echo -e "\033[32m$1\033[m"; }
function cyan { echo -e "\033[36m$1\033[m"; }

if [ $# = 0 ]; then
  red "[ros2 aliases] Give at least one path as an argument."
  red "[Usage 1] source PATH_TO_CLONE/ros2_aliases.bash PATH_TO_ROS_WORKSPACE"
  red "[Usage 2] source PATH_TO_CLONE/ros2_aliases.bash PATH_TO_ROS_WORKSPACE STRING_OF_COLCON_BUILD_CMD"
  red "[Usage 3] source PATH_TO_CLONE/ros2_aliases.bash PATH_TO_CONFIG_FILE"
  return
fi

# config file load function
function load_ros2_aliases_config_yaml {
  source "`dirname $ROS2_ALIASES`/yaml.sh"
  local yaml_string="$(parse_yaml "$1")"
  eval "$(echo "$yaml_string" | sed 's/ROS2_ALIASES_ENVIRONMENT_VARIABLES_\(.*\)=\(.*\)/export \1=\2/g')"
  export ROS_WORKSPACE=$(eval echo "$ROS2_ALIASES_ROS_WORKSPACE")
  export COLCON_BUILD_CMD=$(eval echo "$ROS2_ALIASES_COLCON_BUILD_CMD")
  unset_variables "$yaml_string"
}

# arguments handling
case "$1" in
  *.yaml | *.yml )
    load_ros2_aliases_config_yaml "$1" > /dev/null
    ;;
  * ) 
    export ROS_WORKSPACE=$1
    if [ -n "$2" ]; then
      export COLCON_BUILD_CMD="$2"
    else
      export COLCON_BUILD_CMD="colcon build --symlink-install --parallel-workers $(nproc)"
    fi
    ;;
esac

# error check
if [ ! -d "$ROS_WORKSPACE/src" ]; then
  red "[ros2 aliases] No src directory in the workspace : $ROS_WORKSPACE"
  return
fi
if [[ $COLCON_BUILD_CMD != "colcon build "* ]]; then
  red "Invalid command for colcon build : $COLCON_BUILD_CMD"
  return
fi

# source other scripts
source "`dirname $ROS2_ALIASES`/ros2_utils.bash"
source /opt/ros/$ROS_DISTRO/setup.bash
if [ -e "$ROS_WORKSPACE/install/setup.bash" ]; then
  source $ROS_WORKSPACE/install/setup.bash
fi

# ros2 aliases help
function rahelp {
  green "--- change environments ---"
  echo "`cyan raload` : search and load config for ros2-aliases"
  echo "`cyan chws\ PATH_TO_WORKSPACE` : change ROS 2 workspace"
  echo "`cyan chcbc\ COLCON_BUILD_COMMAND` : change colcon build command with its arguments"
  echo "`cyan chrdi\ ROS_DOMAIN_ID` : change ROS_DOMAIN_ID and ROS_LOCALHOST_ONLY"
  green "--- colcon build ---"
  echo "`cyan cb`    : colcon build"
  echo "`cyan cbp`   : colcon build with packages select"
  echo "`cyan cbcc`   : colcon build with clean cache"
  echo "`cyan cbcf`   : colcon build with clean first"
  green "--- roscd ---"
  echo "`cyan roscd` : cd to the selected package"
  green "--- ROS CLI ---"
  echo "`cyan rnlist` : ros2 node list"
  echo "`cyan rninfo` : ros2 node info"
  echo "`cyan rtlist` : ros2 topic list"
  echo "`cyan rtinfo` : ros2 topic info"
  echo "`cyan rtecho` : ros2 topic echo"
  echo "`cyan rplist` : ros2 param list"
  echo "`cyan rpget`  : ros2 param get"
  echo "`cyan rpset`  : ros2 param set"
  green "--- TF ---"
  echo "`cyan view_frames\ \(namespace\)` : ros2 run tf2_tools view_frames"
  echo "`cyan tf_echo\ \[source_frame\]\ \[target_frame\]\ \(namespace\)` : ros2 run tf2_ros tf2_echo"
  green "--- rosdep ---"
  echo "`cyan rosdep_install` : rosdep install"
  green "--- offical ---"
  echo "`cyan "ros2 -h"` : The Official help"
  green "--- current settings ---"
  echo "`cyan ROS_WORKSPACE` : "$ROS_WORKSPACE""
  echo "`cyan COLCON_BUILD_CMD` : "$COLCON_BUILD_CMD""
}

# ---change environments---
function raload {
  local CONFIG_FILE=`find ~ \( -path "$HOME/.config" -o -name "ros2_aliases.bash" \) -prune -o -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.yaml" -o -name "*.yml" \) -exec grep -l "ROS2_ALIASES" {} + | fzf`
  if [ -n "$CONFIG_FILE" ]; then
    if [[ "$CONFIG_FILE" =~ \.sh$|\.bash$ ]]; then
      source $CONFIG_FILE
    elif [[ "$CONFIG_FILE" =~ \.yaml$|\.yml$ ]]; then
      load_ros2_aliases_config_yaml "$CONFIG_FILE" > /dev/null
    else
      red "*.sh, *.bash, *.yml, or *.yaml is required.*"
      return
    fi
    cyan "Load $CONFIG_FILE"
  fi
}

# change ROS 2 workspace
function chws {
  if [ -n "$1" ]; then
    cd $1 > /dev/null
  fi
  local workspace_candidate=$(pwd)
  if [ ! -d "$workspace_candidate/src" ]; then
    red "[ros2 aliases] No src directory in the workspace : $workspace_candidate"
    return
  fi
  ROS_WORKSPACE=$workspace_candidate
  echo "`cyan ROS_WORKSPACE` : "$ROS_WORKSPACE""
}

# change colcon build
function chcbc {
  if [ $# != 1 ]; then
    red "[Usage] chcbc COLCON_BUILD_CMD"
    echo "current COLCON_BUILD_CMD=\"`cyan "$COLCON_BUILD_CMD"`\""
    echo "default COLCON_BUILD_CMD=\"`cyan "colcon build --symlink-install --parallel-workers $(nproc)"`\""
    return
  fi
  source $ROS2_ALIASES "$ROS_WORKSPACE" "$1"
}

# change ROS_DOMAIN_ID
function chrdi {
  if [ $# != 1 ] || [ $1 -eq 0 ]; then
    export ROS_LOCALHOST_ONLY=1
    echo "ROS_LOCALHOST_ONLY=1"
  else
    export ROS_LOCALHOST_ONLY=0
    export ROS_DOMAIN_ID=$1
    echo "ROS_DOMAIN_ID=$1"
  fi
}

# ---colcon build---
function colcon_build_command_set {
  cd $ROS_WORKSPACE > /dev/null
  cyan "$@"
  $@
  source ./install/setup.bash
  history -s "$@"
}

function cb {
  colcon_build_command_set "$COLCON_BUILD_CMD"
  history -s "cb"
}

function cbcc {
  colcon_build_command_set "$COLCON_BUILD_CMD --cmake-clean-cache"
  history -s "cbcc"
}

function cbcf {
  local cmd="$COLCON_BUILD_CMD --cmake-clean-first"
  cyan "$cmd"
  read -p "Do you want to execute? (y:Yes/n:No): " yn
  case "$yn" in
    [yY]*);;
    *) return ;;
  esac
  colcon_build_command_set "$cmd"
  history -s "cbcf"
}

function cbp {
  if [ $# -eq 0 ]; then
    local pkg_name=$(find $ROS_WORKSPACE/src -name "package.xml" -print0 | while IFS= read -r -d '' file; do grep -oP '(?<=<name>).*?(?=</name>)' "$file"; done | fzf)
    [[ -z "$pkg_name" ]] && return
  else
    local pkg_name="$@"
  fi
  colcon_build_command_set "$COLCON_BUILD_CMD --packages-select $pkg_name"
  history -s "cbp $pkg_name"
}
_pkg_name_complete() {
  local cur prev opts
  _get_comp_words_by_ref cur prev
  opts=$(find $ROS_WORKSPACE/src -name "package.xml" -print0 | while IFS= read -r -d '' file; do grep -oP '(?<=<name>).*?(?=</name>)' "$file"; done) # tha same as $pkg_name
  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
}
complete -F _pkg_name_complete cbp

# ---roscd---
function roscd {
  if [ $# -eq 0 ]; then
    local pkg_dir_name=$(find $ROS_WORKSPACE/src -name "package.xml" -printf "%h\n" | awk -F/ '{print $NF}' | fzf)
    [[ -z "$pkg_dir_name" ]] && cd $ROS_WORKSPACE && return
    history -s "roscd $pkg_dir_name"
  else
    local pkg_dir_name=$1
  fi
  local pkg_dir=$(find $ROS_WORKSPACE/src -name $pkg_dir_name | awk '{print length() ,$0}' | sort -n | awk '{ print  $2 }' | head -n 1)
  [[ -z $pkg_dir ]] && red "$pkg_dir_name : No such package" && return
  cd $pkg_dir
}
_pkg_name_sub_directory_complete() {
  local cur prev opts
  _get_comp_words_by_ref cur prev
  opts=$(find $ROS_WORKSPACE/src -name "package.xml" -printf "%h\n" | awk -F/ '{print $NF}') # tha same as $pkg_dir_name
  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
}
complete -o nospace -F _pkg_name_sub_directory_complete roscd

# ---rosdep---
alias rosdep_install="cd $ROS_WORKSPACE && rosdep install --from-paths src --ignore-src -y"

# ---pkg---
alias rpkgexe="ros2 pkg executables"

# ---Pull request to ros2_utils---
# ros2 interface
function rishow {
  local INTERFACE=$(ros2 interface list | fzf | sed 's/ //g')
  [[ -z "$INTERFACE" ]] && return
  local cmd="ros2 interface show $INTERFACE"
  echo $cmd
  $cmd
  history -s rishow
  history -s $cmd
}
