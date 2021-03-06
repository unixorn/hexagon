autoload -U add-zsh-hook

hexagon::color() {
  (($# - 2)) || echo -n %F{$1}$2%f
}

hexagon::format() {
  local seconds=$1
  local days=$((seconds / 60 / 60 / 24))
  local hours=$((seconds / 60 / 60 % 24))
  local minutes=$((seconds / 60 % 60))
  local seconds=$((seconds % 60))

  local -a human=()
  local color

  ((days > 0)) && human+=${days}d && color=red
  ((hours > 0)) && human+=${hours}h && : ${color:=white}
  ((minutes > 0)) && human+=${minutes}m
  ((seconds > 0)) && human+=${seconds}s && : ${color:=green}

  hexagon::color $color $human[1]
}

zmodload zsh/datetime zsh/stat

HEXAGON_TIME_FILE=$(mktemp)

hexagon::command_start() {
  touch $HEXAGON_TIME_FILE
}

add-zsh-hook preexec hexagon::command_start

hexagon_timer() {
  [[ -z $HEXAGON_TIME_FILE ]] && return
  [[ -f $HEXAGON_TIME_FILE ]] || return

  local atime=$(zstat +atime $HEXAGON_TIME_FILE)
  local elapsed

  rm -f $HEXAGON_TIME_FILE

  ((elapsed = $EPOCHSECONDS - $atime))
  ((elapsed > 5)) && hexagon::format $elapsed
}

hexagon_jobs() {
  [[ 0 -ne $(jobs | wc -l) ]] && hexagon::color blue '⚙ %(1j.%j.-)'
}

hexagon_git_time() {
  local last_commit=$(git log -1 --pretty=format:'%at' 2> /dev/null)

  [[ -z $last_commit ]] && hexagon::color default welcome && return

  local now=$(date +%s)
  local seconds_since_last_commit=$((now - last_commit))

  hexagon::format $seconds_since_last_commit
}

hexagon_git_branch() {
  hexagon::color 242 $(git symbolic-ref --short HEAD 2> /dev/null || git rev-parse --short HEAD)
}

hexagon_git_status() {
  [[ -z $(git status --porcelain --ignore-submodules HEAD) ]] \
  && [[ -z $(git ls-files --others --modified --exclude-standard $(git rev-parse --show-toplevel)) ]] \
  && hexagon::color green ⬢ || hexagon::color red ⬡
}

hexagon_git_remote() {
  local unpushed=⇡
  local unpulled=⇣
  local local_commit=$(git rev-parse @ 2> /dev/null)
  local remote_commit=$(git rev-parse @{u} 2> /dev/null)

  [[ $local_commit == @ || $local_commit == $remote_commit ]] && return

  local common_base=$(git merge-base @ @{u} 2> /dev/null)

  [[ $common_base == $remote_commit ]] && echo -n $unpushed && return
  [[ $common_base == $local_commit ]]  && echo -n $unpulled && return

  echo -n $unpushed $unpulled
}

hexagon_git() {
  git rev-parse --git-dir &> /dev/null || return

  $(git rev-parse --is-bare-repository 2> /dev/null) && hexagon::color blue ⬢ && return

  echo -n $(hexagon_git_remote) $(hexagon_git_branch) $(hexagon_git_time) $(hexagon_git_status)
}

hexagon::render() {
  local -a output=(
    $(hexagon_timer)
    $(hexagon_jobs)
    $(hexagon_git)
  )

  PROMPT=$(hexagon::color blue "%2~ ")
  RPROMPT=${(ps. .)output}
}

add-zsh-hook precmd hexagon::render
