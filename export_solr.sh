#!/bin/bash

###
#
# export_solr.sh
#
# by Michael Kubina (https://github.com/michaelkubina)
#
# 15.02.2022
#
###
 
# Requirements:
# stop any indexing! (otherwise our snapshot misses the last indexed documents)
# curl / sudo apt-get install curl
# jq (we need it later for the transformation into the solr-compatible import format) / sudo apt-get install jq
 
# params
user=""
password=""
url="http://localhost:8983/solr"
core="<NAME_OF_CORE>"
chunksize=1000
 
echo "EXPORTING START"
# create export-folder
mkdir -p export_$core
 
# load and save response header
touch export_$core/response_header.json
#curl --user $user:$password -o "export_$core/response_header.json" "$url/select?q=*%3A*&rows=0&start=0&wt=json"
curl -s -S --user $user:$password -o "export_$core/response_header.json" "$url/$core/select?q=*%3A*&rows=0&start=0&wt=json" > /dev/null
 
# determine number of chunks
#max_documents=`grep "numFound" export_$core/response_header.json | sed 's/  "response":{"numFound"://' | sed 's/,.*//'`
max_documents=`jq '.response.numFound' "export_$core/response_header.json"`
max_chunks=$(($max_documents/$chunksize))
max_chunks=$(($max_chunks+1))
 
#echo "Documents in SOLR: $max_documents"
#echo "Chunksize: $chunksize"
#echo "Number of chunks: $max_chunks"
 
# create chunks
counter=0

while [ $counter -ne $max_chunks ]
do
    touch export_$core/chunk_$counter.json
    start_position=$(($chunksize*$counter))
    #curl -s -S --user $user:$password -o "export_$core/chunk_$counter.json" "$url/select?q=*%3A*&rows=$chunksize&sort=id%20asc&start=$start_position&wt=json" > /dev/null
     
    # sort not necessary as *:* sorts by the same order the documents were stored/uploaded into the index
    curl -s -S --user $user:$password -o "export_$core/chunk_$counter.json" "$url/$core/select?q=*%3A*&rows=$chunksize&start=$start_position&wt=json" > /dev/null
    counter=$(($counter+1))
done
echo "EXPORTED $max_documents DOCUMENTS IN $max_chunks CHUNKS"
echo "EXPORTING DONE"

echo "PROCESSING START"
documents_processed=0
for file in export_$core/*.json
do
    # backup all files first
    cp $file $file.bak
done

for file in export_$core/*.json
do
    # determine number of documents
    documents_in_chunk=`grep '"id":' $file | wc -l`
    # catch all documents as list and ignore everything above
    jq '.response.docs' $file > $file.tmp && mv $file.tmp $file
    documents_processed=$(($documents_processed+$documents_in_chunk))
    echo "$file"
    echo -ne "$documents_processed"\\r
done
echo "PROCESSED $documents_processed DOCUMENTES"
echo "PROCESSING DONE"
