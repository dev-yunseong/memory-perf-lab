#!/usr/bin/env bash

set -euo pipefail

CORE=${CORE:-3}
REPS=${REPS:-5}
ITERS=${ITERS:-200000000}

echo "bytes, rep, ns"

for pow in $(seq 12 26); do # 4KB 64MB까지 테스트 
	bytes=$((1 << pow))

	for rep in $(seq 1 $REPS); do
		out=$(taskset -c "$CORE" ./latency "$bytes" "$ITERS" 2>/dev/null) # taskset -c 를 통해서 core를 고정
		echo "${out%,*}, ${rep}, ${out#*,}"
	done
done
