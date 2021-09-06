#!/bin/sh
ls -ARl | egrep "^[-d]" | sort -rn -k 5,5 | awk 'BEGIN{total_size=0; total_dir=0; total_regfile=0; line=1}  /^-/ {total_size=total_size+$5}  /^-/ && line < 6 {print line ":" $5, $9 ; line=line+1 ; } /^-/ {total_regfile=total_regfile+1}  /^d/ {total_dir=total_dir+1} END{print  "Dir num:", total_dir, "\nFile num:" total_regfile,"\nTotal:", total_size }'
