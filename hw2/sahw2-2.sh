#!/bin/sh

: ${DIALOG_CANCEL=1}
human_readable() {
	local SIZE=$1
	local UNITS="B KB MB GB TB EB PB YB ZB"
	for F in $UNITS; do
		local UNIT=$F
		test ${SIZE%.*} -lt 1024 && break;
		SIZE=$(echo "$SIZE / 1024" | bc -l)
	done
	echo "$(printf "%.2f%s\n" $SIZE $UNIT)"
}
cpu_info() {
	info="CPU Info\n";
	info=${info}"CPU Model:";
	info=${info}$(sysctl -a | egrep 'hw.model' | cut -d : -f 2)"\n";
	info=${info}"CPU Machine:"$(sysctl -a | egrep 'hw.machine_arch' | cut -d : -f 2)"\n";
	info=${info}"CPU Core:"$(sysctl -a | egrep 'hw.ncpu' | cut -d : -f 2)"\n";
	dialog --msgbox "$info" 25 70 
}

memory_usage() {
	info="Memory Info and Usage\n\n";
	total_memory=$(sysctl -n hw.realmem)
	free_memory=$(grep memory /var/run/dmesg.boot | cut -d ' ' -f 4 | tail -1)
	used_memory=$((total_memory-free_memory))
#	human_readable $total_memory
	info=${info}"Total: "$(human_readable $total_memory)"\n"
	info=${info}"Free: "$(human_readable $free_memory)"\n"
	info=${info}"Used: "$(human_readable $used_memory)"\n"
	percentage=$((used_memory*100/free_memory))
	dialog --mixedgauge "$info" 25 70 $percentage
	read _
}

net_info(){
	while true; do
		exec 3>&1
		total_line=$(ifconfig | egrep -c "^[A-Za-z]")
		all_network=""
		i=1;
		while [ $i -le $total_line ]
		do
			all_network=${all_network}$(ifconfig | egrep "^[A-Za-z]" | head -$i | tail -1 | cut -d : -f 1 )" * "
			i=$((i+1))
		done
		set -f
		selection=$(dialog --menu 'Network Interfaces' 25 70 5 $all_network 2>&1 1>&3)

		exit_status=$?
		exec 3>&-
		case $exit_status in
			$DIALOG_CANCEL) break;;
		esac
		i=1
		info=""
		while [ $i -le $total_line ]
		do
			label=$(ifconfig | egrep "^[A-Za-z]" | head -$i | tail -1 | cut -d : -f 1 )
			if [ "$selection" = "$label" ] 
			then
				j=$((i+1))
				info=${info}"Interface Name: ";
				info=${info}$(ifconfig | egrep "^[A-Za-z]" | head -$i | tail -1 | cut -d : -f 1 )"\n\n";
				info_line=$(ifconfig | egrep -n "^[A-Za-z]" | head -$i | tail -1 | cut -d : -f 1)
				next_info_line=$(ifconfig | egrep -n "^[A-Za-z]" | head -$j | tail -1 | cut -d : -f 1)
				set +f
				total_line=$(ifconfig | egrep -n "^*" | tail -1 | cut -d : -f 1)
				tail_line=$((total_line-info_line+1))
				head_line=$((next_info_line-1))
				info=${info}"IPv4___: "$(ifconfig | tail -$tail_line | head -$head_line | egrep -w "inet" | cut -d ' ' -f 2)"\n";
				info=${info}"Netmask: "$(ifconfig | tail -$tail_line | head -$head_line | egrep -w "inet" | cut -d ' ' -f 4)"\n";
				info=${info}"Mac____: "$(ifconfig | tail -$tail_line | head -$head_line | egrep -w "ether" | cut -d ' ' -f 2)"\n";
				break;
			fi
			i=$((i+1))
		done
		dialog --msgbox "$info" 25 70
	done
}

file_select(){
	exec 3>&1
	directory=$1
	info=". inode/directory "
	if [ "$directory" != '/' ]
	then
		info=${info}".. inode/directory "
	fi
	all_files=$(ls -Al | awk '{print $9}')
	info=${info}$(file --mime-type $all_files | sed 's/:/ /g'| awk ' {print $1 " " $2 " " }')
	selection=$(dialog --menu "File Browser: $directory" 50 70 50 $info 2>&1 1>&3 )
	exit_status=$?
	exec 3>&-
	case $exit_status in
		$DIALOG_CANCEL) return;; 
	esac
	selection_type=$(ls -Al | egrep "^[d]" |egrep -w "$selection")
	if [ -n "$selection_type"  ] || [ "$selection" = ".." ] || [ "$selection" = '.' ]
	then
		cd $selection
	else 
		info="<File Name>: "$selection"\n"
		info=${info}"<File Info>:"$(file $selection | cut -d ':' -f 2)"\n"
		file_size=$(ls -Al | egrep -w $selection | awk '{print $5;}')
		info=${info}"<File Size>: "$(human_readable $file_size)
		set +f
		if [ "$(file --mime-type $all_files | egrep "$selection" |awk '{print $2}' | cut -d / -f 1)" = "text" ]
		then
			while true;
			do
				dialog --yes-label "Ok" --no-label "Edit" --yesno "$info" 25 70
				if [ $? -eq 0 ]
				then
					break;
				else
					$EDITOR $selection		
				fi
			done
		else
			dialog --msgbox "$info" 25 70
		fi
		
	fi
	file_select $(pwd)
}

cpu_usage() {
	info="CPU Loading\n"
	i=0
	used=0
	total_used=0
	core=$(sysctl -a | egrep 'hw.ncpu' | cut -d : -f 2)
	while [ $i -lt $core ];
	do
		info=${info}"CPU"$(top -P | head -$((i+3)) | tail -1 | awk '{print $2}')" "
		info=${info}"USER: "$(top -P | head -$((i+3)) | tail -1 | awk '{print $3+$5}')"% "
		info=${info}"SYSTEM: "$(top -P | head -$((i+3)) | tail -1 | awk '{print $7+$9}')"% "
		info=${info}"IDLE: "$(top -P | head -$((i+3)) | tail -1 | awk '{print $11}')
		info=${info}"\n"
		used=$(top -P | head -$((i+3)) | tail -1 | awk '{print $3*100+$5*100+$7*100+$9*100}')
		number=0
		while [ $number -lt $used ];
		do 
			total_used=$((total_used+1))
			number=$((number+1))
		done
		i=$((i+1))
	done
	percentage=$(echo "$((total_used/core))")
	if [ $percentage -gt 100 ] 
	then
		percentage=$(echo "$((percentage/100))" | bc -l)
	elif [ $percentage -gt 50 ]
	then
		percentage=1
	else
		percentage=0
	fi
	dialog --mixedgauge "$info" 25 70 $percentage
	read _
}
GLOBIGNORE="*"
curl_opts="-s --noproxy * -O"
curl $curl_opts "$1"
trap "clear;exit 1" 2
directory_index=$(pwd)
while true; do
	exec 3>&1
	cd $directory_index
	selection=$(dialog --menu "SYS INFO" 25 70 25 1 "CPU INFO" 2 "MEMORY INFO" 3 "NETWORK INFO" 4 "FILE BROWSER" 5 "CPU USAGE" 2>&1 1>&3 )
	exit_status=$?
  	exec 3>&-
  	case $exit_status in
	     $DIALOG_CANCEL) clear;exit 0;;
     	esac
	case $selection in
		1) cpu_info;;
		2) memory_usage;;
		3) net_info;;
		4) file_select $directory_index;;
		5) cpu_usage;;
	esac
done
