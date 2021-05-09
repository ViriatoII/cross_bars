#PBS -l select=1:ncpus=4:mem=6G
#PBS -l walltime=59:00:00
#PBS -A "C4Evol"


module load SamTools bcftools/1.10.2  #bedtools/2.26.0


cd $PBS_O_WORKDIR         # ENTER SCRIPT DIRECTORY


## Variable INPUTs 
contig="contig_name" # Only working for one specific contig/scaffold. Automate? 
ref="refs/reference.fasta"

refname=`echo "$ref" | sed 's/.*\/// ; s/.fasta//'`

# Names of all breeds from header of snp_matrix
breeds_ite=`head -1  snp_matrix.csv | sed 's/P.*REF,//' | tr "," "\n" `


## Receive input part from 00_run_fill_amb_pos.sh 
part=${PART:4:1}   # Gets 5th letter of PART*: a,b,c, etc..    
tmp="tmp$part"
mkdir $tmp         # Each part is saved here before final merge.


# Iterate through input SNP matrix 
for line in `cat $PART `      
	do
	pos=`echo "$line" | cut -f1 -d "," `
	len=`echo "$line" | cut -f2 -d "," |  wc | sed 's/.* //'  `	

	# prepare a bed file to extract exact nucleotide in question
        echo "$contig $((pos-1)) $((pos+len-2))" | tr " " "\t" > $tmp/tmp.bed ; wait

	# Position and ref for later pasting
	echo $line  | cut -f1,2 -d,  >> $tmp/positions.txt  

	colnum=2 # counter starts at 2 (after pos and ref)

	# Get input bams and for each breed
        for breed in $breeds_ite   
                do
		
		# counter updates per breed, resets per line
		let "colnum+=1"

		# Only apply to empty SNPs.
		if [ `echo "$line" | cut -f$colnum -d, ` == "-" ] ; then
	
			#Extract mappings spanning position
                	samtools view -@ 3  -h extract_regions/pseudomols/ragoo_${breed}_trimreads_vs_$refname/contigs_against_ref.bam $contig:$pos-$pos  > $tmp/reads.sam  ; wait

	                #Generate consensus from mapped reads
        	        samtools mpileup  -uf  $ref  $tmp/reads.sam | bcftools call -c  --threads 4 | vcfutils.pl vcf2fq > $tmp/consensus.fastq ; wait
                	seqtk seq -aQ64 $tmp/consensus.fastq > $tmp/consensus.fasta  # transform to fasta. To make low qual reads(<20) --> N    -q20 -n N
		
	                #Extract sequence in exact coordinates
        	        sequence2=`bedtools getfasta -fi  $tmp/consensus.fasta  -bed $tmp/tmp.bed | tail -1 `

		else    #Use called SNP of snp_matrix line.
			sequence2=`echo "$line" | cut -f$colnum -d, ` ; fi 
		
		# Print SNP into temporary files 
                echo "$sequence2" >> $tmp/$breed.csv ; wait
       		rm $tmp/consensus*

                done
	done