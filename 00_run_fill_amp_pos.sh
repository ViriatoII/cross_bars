
# Split  snp_matrix.csv into parts: PARTa, PARTb, PARTc, etc..

grep "-" snp_matrix.csv  | split - PART  -l 1000 -a 1 --additional-suffix=.csv 


# Start a qsub job for each part
for PART_file in PAR* 
	do 


	echo "Correcting $PART_file" 
	qsub -v PART="$PART_file"  00_fill_ambiguous_pos.sh &

done


################# After all parts are finished:  MERGE THEM #####################

echo " PLEASE RUN:  

head  -1 snp_matrix.csv > snp_matrix_corrections.csv

for folder in  tmp*/
        do

        paste -d ','  $folder/positions.txt  $folder/*csv  | sed 's/c/C/g ; s/a/A/g ; s/g/G/g ; s/t/T/g' >> t.csv

        done


sed 's/,.*//' t.csv   | sort -Vu > t2
grep -vf t2  snp_matrix.csv | grep -v 'REF' >>  t.csv

sort -V -t, -k1 t.csv | uniq  >> snp_matrix_corrections.csv  ; rm t.csv t2
"

