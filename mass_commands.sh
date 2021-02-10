#! /bin/bash
if ! command -v terminus &> /dev/null
then
    echo "Terminus could not be found."
    echo "Plase add terminus location to your PATH variable"
    exit
fi

echo "Here are the available Terminus commands:"
TERMINUS_COMMANDS=(cache-clear updb apply-upstream deploy)
OPTIONS=();
for ((i=0; i < ${#TERMINUS_COMMANDS[@]}; i+=1))
do
  echo "($i) -> ${TERMINUS_COMMANDS[i]}"
  OPTIONS+=($i)
done

read -p "Please choose the Terminus command you would like to run: " selected
while [[ ! " ${OPTIONS[@]} " =~ " ${selected} " ]]; do
  echo "Wrong command."
  read -p "Please choose the Terminus command you would like to run: " selected
done
echo "You have chosen ${TERMINUS_COMMANDS[selected]}"



echo -e "\033[1;34mLogging into Pantheon...\033[0m"
terminus auth:login 2>&1

IFS=$'\n' read -r -d '' -a all_sites < <(terminus site:list --field name && printf '\0' )
upstreams=()
repos=()
FILE="upstreams.txt"
REPOS="repos.txt"
if [ -f "$FILE" ]; then
    TOTAL_SITES=$(head -n 1 $FILE)
    { read -r;
    while IFS= read -r line
    do
      upstreams+=($line)
    done } < $FILE
    while IFS= read -r line
    do
      repos+=($line)
    done < $REPOS
    if [[ "${#all_sites[@]}" =~ "${TOTAL_SITES}" ]]; then
      echo "You still have access to ${TOTAL_SITES} sites. The same number since last time."
    else
      echo "You have now access to ${#all_sites[@]} but previously you had access to ${TOTAL_SITES}"
    fi
else
    echo "${#all_sites[@]}" >> $FILE
    echo "You have access to ${#all_sites[@]} sites."
    echo "Fetching upstream IDs:"
    echo "Total sites scanned 0/${#all_sites[@]}. Upstreams found: 0"
    COUNT_UPSTREAMS=0;
    for ((i=0; i < ${#all_sites[@]}; i+=1))
    do
     echo -e "\e[1A\e[KTotal sites scanned $i/${#all_sites[@]}. Upstreams found: ${COUNT_UPSTREAMS}"
     repo=$(terminus site:info "${all_sites[i]}" --field upstream | awk -F': ' '{print $2}')
     value=$(terminus site:info "${all_sites[i]}" --field upstream | egrep -o '^[^:]+')
      if [[ ! " ${upstreams[@]} " =~ " ${value} " ]]; then
        COUNT_UPSTREAMS=$((COUNT_UPSTREAMS+1));
        upstreams+=($value)
        repos+=($repo)
        echo $value >> $FILE
        echo $repo >> $REPOS
      fi
    done
fi
printf  "\n\n"
echo "These are the custom upstreams from your sites."
OPTIONS=()
for ((i=0; i < ${#upstreams[@]}; i+=1))
do
   echo "($i)->${upstreams[i]}: ${repos[i]}"
   OPTIONS+=($i)
done
printf "\n\n"

read -p "Please, choose an upstream: " uid
while [[ ! " ${OPTIONS[@]} " =~ " ${uid} " ]]; do
  echo "Wrong option."
  read -p "Please, choose an upstream: " uid
done
printf "\n\n"
echo "You have chosen upstream ${upstreams[$uid]}"


echo -e "\033[1;34mFetching Site List for error checking...\n\033[0m"
IFS=$'\n' read -r -d '' -a my_sites < <(terminus site:list --field name --upstream "${upstreams[$uid]}" && printf '\0' )
for ((i=0; i < ${#my_sites[@]}; i+=1))
do
  case "${TERMINUS_COMMANDS[selected]}" in

  cache-clear)
    COMMAND="terminus env:clear-cache -- ${my_sites[i]}.dev"
     echo "Executing: "$COMMAND
     #terminus env:clear-cache -- ${my_sites[i]}.dev &
    ;;
  updb)
    COMMAND="terminus remote:drush -- ${my_sites[i]}.dev updb --yes"
     echo "Executing: "$COMMAND
     #terminus remote:drush -- ${my_sites[i]}.dev updb --yes &
    ;;
  apply-upstream)
     COMMAND="terminus upstream:updates:apply --accept-upstream -- ${my_sites[i]}.dev"
     echo "Executing: "$COMMAND
     #terminus upstream:updates:apply --accept-upstream -- ${my_sites[i]}.dev &
    ;;
  deploy)
    COMMAND="terminus env:deploy -- ${my_sites[i]}.test"
     echo "Executing: "$COMMAND
     #terminus env:deploy -- ${my_sites[i]}.dev &
    ;;
  esac


  if [[ ! $? -eq 0 ]]; then
    echo -e "\033[1;31m${my_sites[i]}: failed.\033[0m"
    ERROR_SITES+="${my_sites[i]} \n"
    continue
  fi
done

