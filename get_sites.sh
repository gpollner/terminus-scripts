#! /bin/bash
echo -e "\033[1;34mLogging into Pantheon...\033[0m"
terminus auth:login 2>&1
IFS=$'\n' read -r -d '' -a all_sites < <(terminus site:list --field name && printf '\0' )
upstreams=()
FILE="upstreams.txt"
if [ -f "$FILE" ]; then
    TOTAL_SITES=$(head -n 1 $FILE)
    { read -r;
    while IFS= read -r line
    do
      upstreams+=($line)
    done } < $FILE
    if [[ "${#all_sites[@]}" =~ "${TOTAL_SITES}" ]]; then
      echo "You still have access to ${TOTAL_SITES} sites. The same number since last time."
    else
      echo "You have now access to ${#all_sites[@]} but previously you had access to ${TOTAL_SITES}"
    fi
else
    echo "${#all_sites[@]}" >> $FILE
    echo "You have access to ${#all_sites[@]} sites."
    echo "Fetching upstream IDs:"
    echo "Total sites scanned 0/${#all_sites[@]}"
    for ((i=0; i < ${#all_sites[@]}; i+=1))
    do
     echo -e "\e[1A\e[KTotal sites scanned $i/${#all_sites[@]}"
     value=$(terminus site:info "${all_sites[i]}" --field upstream | egrep -o '^[^:]+')
      if [[ ! " ${upstreams[@]} " =~ " ${value} " ]]; then
        upstreams+=($value)
        echo $value >> $FILE
      fi
    done
fi
for ((i=0; i < ${#upstreams[@]}; i+=1))
do
   printf "($i)->"
   printf "${upstreams[i]} \n "
done
printf "\n\n"
printf "Please, choose an upstream: "
read uid
echo "You have chosen upstream ${upstreams[$uid]}"

terminus auth:login 2>&1
echo -e "\033[1;34mFetching Site List for error checking...\n\033[0m"
IFS=$'\n' read -r -d '' -a my_sites < <(terminus site:list --field name --upstream "${upstreams[$uid]}" && printf '\0' )
g=2
echo "Please choose one site:"
for ((i=0; i < ${#my_sites[@]}; i+=1))
do
   printf "($i)->"
   printf "${my_sites[i]}, "
done
printf "\n\n"
printf "Site: "
read site
echo "You have chosen site ${my_sites[$site]}"
terminus site:info ${my_sites[$site]}
