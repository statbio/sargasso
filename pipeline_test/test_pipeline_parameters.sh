#!/bin/bash

set -o nounset
set -o errexit

NUM_THREADS=1

function test_expected_results {
    SPECIES_ID=$1
    EXPECTED_RESULTS_STRING=$2
    MISMATCH_THRESHOLD=$3
    MINMATCH_THRESHOLD=$4
    MULTIMAP_THRESHOLD=$5

    if ! grep --quiet "${EXPECTED_RESULTS_STRING}" ${LOG_FILE}; then
      echo "For mismatch-threshold=${MISMATCH_THRESHOLD}, minmatch-threshold=${MINMATCH_THRESHOLD}, multimap-threshold=${MULTIMAP_THRESHOLD}"
      echo "Expected: ${EXPECTED_RESULTS_STRING}"

      grep_res=$(grep "Species ${SPECIES_ID}:" ${LOG_FILE})
      echo "Got: ${grep_res}"
      exit 1
    fi
}

function expected_results {
    SPECIES_ID=$1
    FILTERED_HITS_EXPECTED=$2
    FILTERED_READS_EXPECTED=$3
    REJECTED_HITS_EXPECTED=$4
    REJECTED_READS_EXPECTED=$5
    AMBIGUOUS_HITS_EXPECTED=$6
    AMBIGUOUS_READS_EXPECTED=$7

    echo "Species ${SPECIES_ID}: wrote ${FILTERED_HITS_EXPECTED} filtered hits for ${FILTERED_READS_EXPECTED} reads; ${REJECTED_HITS_EXPECTED} hits for ${REJECTED_READS_EXPECTED} reads were rejected outright, and ${AMBIGUOUS_HITS_EXPECTED} hits for ${AMBIGUOUS_READS_EXPECTED} reads were rejected as ambiguous."
}

MAIN_DIR=$(pwd)

DATA_DIR=${MAIN_DIR}/data
RAW_READS_DIR=${DATA_DIR}/fastq
PRESORTED_READS_DIR=${DATA_DIR}/bam

RESULTS_DIR=${MAIN_DIR}/results
SSS_DIR=${RESULTS_DIR}/sss
SSS_SORTED_DIR=${SSS_DIR}/sorted_reads
SAMPLES_FILE=${RESULTS_DIR}/samples.tsv
LOG_FILE=${RESULTS_DIR}/log.txt

ENSEMBL_VERSION=83
MOUSE_GENOME_DIR=/srv/data/genome/mouse/ensembl-${ENSEMBL_VERSION}
MOUSE_STAR_INDEX=${MOUSE_GENOME_DIR}/STAR_indices/primary_assembly
RAT_GENOME_DIR=/srv/data/genome/rat/ensembl-${ENSEMBL_VERSION}
RAT_STAR_INDEX=${RAT_GENOME_DIR}/STAR_indices/toplevel

MISMATCH_THRESHOLD=$1
MINMATCH_THRESHOLD=$2
MULTIMAP_THRESHOLD=$3
REJECT_MULTIMAPS=$4
REJECT_EDITS=$5

MOUSE_FILTERED_HITS_EXPECTED=$6
MOUSE_FILTERED_READS_EXPECTED=$7
MOUSE_REJECTED_HITS_EXPECTED=$8
MOUSE_REJECTED_READS_EXPECTED=$9

RAT_FILTERED_HITS_EXPECTED=${10}
RAT_FILTERED_READS_EXPECTED=${11}
RAT_REJECTED_HITS_EXPECTED=${12}
RAT_REJECTED_READS_EXPECTED=${13}

AMBIGUOUS_HITS_EXPECTED=${14}
AMBIGUOUS_READS_EXPECTED=${15}

RUN_STAR=${16}

rm -rf ${RESULTS_DIR}
mkdir -p ${RESULTS_DIR}

echo "sample_reads ${RAW_READS_DIR}/mouse_rat_test_1.fastq.gz ${RAW_READS_DIR}/mouse_rat_test_2.fastq.gz" > ${SAMPLES_FILE}

if [[ "${REJECT_MULTIMAPS}" == "true" ]]; then
    REJECT_MULTIMAPS="--reject-multimaps"
else
    REJECT_MULTIMAPS=""
fi

if [[ "${REJECT_EDITS}" == "true" ]]; then
    REJECT_EDITS="--reject-edits"
else
    REJECT_EDITS=""
fi

species_separator --reads-base-dir="/" --s1-index=${MOUSE_STAR_INDEX} --s2-index=${RAT_STAR_INDEX} -t ${NUM_THREADS} --mismatch-threshold=${MISMATCH_THRESHOLD} --minmatch-threshold=${MINMATCH_THRESHOLD} --multimap-threshold=${MULTIMAP_THRESHOLD} ${REJECT_MULTIMAPS} ${REJECT_EDITS} mouse rat ${SAMPLES_FILE} ${SSS_DIR}

if [[ ! "${RUN_STAR}" == "yes" ]]; then
    mkdir -p ${SSS_DIR}/star_indices/mouse
    mkdir -p ${SSS_DIR}/star_indices/rat
    mkdir -p ${SSS_DIR}/raw_reads
    mkdir -p ${SSS_DIR}/mapped_reads
    mkdir -p ${SSS_SORTED_DIR}
    cp ${PRESORTED_READS_DIR}/*.bam ${SSS_SORTED_DIR}
fi

(cd ${SSS_DIR}; make >${LOG_FILE} 2>&1) 

MOUSE_INFO_EXPECTED=$(expected_results 1 ${MOUSE_FILTERED_HITS_EXPECTED} ${MOUSE_FILTERED_READS_EXPECTED} ${MOUSE_REJECTED_HITS_EXPECTED} ${MOUSE_REJECTED_READS_EXPECTED} ${AMBIGUOUS_HITS_EXPECTED} ${AMBIGUOUS_READS_EXPECTED})

RAT_INFO_EXPECTED=$(expected_results 2 ${RAT_FILTERED_HITS_EXPECTED} ${RAT_FILTERED_READS_EXPECTED} ${RAT_REJECTED_HITS_EXPECTED} ${RAT_REJECTED_READS_EXPECTED} ${AMBIGUOUS_HITS_EXPECTED} ${AMBIGUOUS_READS_EXPECTED})

test_expected_results 1 "${MOUSE_INFO_EXPECTED}" ${MISMATCH_THRESHOLD} ${MINMATCH_THRESHOLD} ${MULTIMAP_THRESHOLD}
test_expected_results 2 "${RAT_INFO_EXPECTED}" ${MISMATCH_THRESHOLD} ${MINMATCH_THRESHOLD} ${MULTIMAP_THRESHOLD}