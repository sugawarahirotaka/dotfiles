nvistat() {
  local -a servers
  local server

  servers=("v101" "v102" "v103" "v104" "v105" "v106" "v107" "v108")
  for server in "${servers[@]}"; do
    echo "${fg_bold[green]}$server${reset_color}:"
    ssh -x "$server" \
      nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory --format=csv,noheader \
      | sed \
        -e 's/NVIDIA //g' \
        -e 's/Tesla //g' \
        -e 's/ %/%/g' \
        -e 's/Graphics Device/A100 80GB PCIe/g' \
        -e "s/ 0%/ ${fg_bold[cyan]}0${reset_color}%/g" \
        -e "s/ 100%/${fg_bold[red]} 100${reset_color}%/g" \
      | while IFS=, read -r id gpu load mem; do
          printf "%4s %16s [%4s] [%4s]\n" "$id" "$gpu" "$load" "$mem"
        done
  done
}
