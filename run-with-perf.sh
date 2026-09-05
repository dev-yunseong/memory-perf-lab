#!/usr/bin/env bash

set -euo pipefail

CORE=${CORE:-3}
REPS=${REPS:-5}
ITERS=${ITERS:-200000000}
POW_MIN=${POW_MIN:-12}  # 2^12 = 4KB
POW_MAX=${POW_MAX:-25}  # 2^25 = 32MB

# 로드 uop이 어느 계층에서 처리됐는지 세는 이벤트 + cycles
EVENTS="mem_load_uops_retired.l1_hit,mem_load_uops_retired.l1_miss"
EVENTS+=",mem_load_uops_retired.l2_hit,mem_load_uops_retired.l2_miss"
EVENTS+=",mem_load_uops_retired.l3_hit,mem_load_uops_retired_misc.l3_miss"
EVENTS+=",mem_load_uops_retired.dram_hit,cycles"

if [ -t 1 ]; then
	BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
	BOLD=""; DIM=""; RESET=""
fi

perf_out=$(mktemp)
rows=$(mktemp)
trap 'rm -f "$perf_out" "$rows"' EXIT

# 4096 -> 4KB, 33554432 -> 32MB
human() {
	local b=$1
	if   (( b >= 1 << 20 )); then echo "$(( b >> 20 ))MB"
	elif (( b >= 1 << 10 )); then echo "$(( b >> 10 ))KB"
	else                          echo "${b}B"
	fi
}

# perf -x, 출력에서 이벤트 값을 꺼낸다. 못 센 이벤트는 -1.
counter() {
	awk -F, -v ev="$1" '
		$3 ~ ("^" ev ":?") { print ($1 ~ /^[0-9]+$/) ? $1 : -1; found = 1; exit }
		END { if (!found) print -1 }
	' "$perf_out"
}

# 한 줄을 표 모양으로 찍고, 같은 값을 요약용 파일에도 남긴다.
print_row() {
	awk -v size="$1" -v rep="$2" -v ns="$3" -v cycles="$4" -v iters="$5" \
	    -v l1h="$6" -v l1m="$7" -v l2h="$8" -v l3h="$9" -v dram="${10}" \
	    -v rows="${11}" -v dim="$DIM" -v reset="$RESET" '
		function commify(x,   s, out) {
			if (x < 0) return "-"
			s = sprintf("%.0f", x); out = ""
			while (length(s) > 3) {
				out = "," substr(s, length(s) - 2) out
				s = substr(s, 1, length(s) - 3)
			}
			return s out
		}
		function pct(hit, total) {
			return (hit < 0 || total <= 0) ? "-" : sprintf("%.2f", 100 * hit / total)
		}
		BEGIN {
			total = (l1h >= 0 && l1m >= 0) ? l1h + l1m : -1
			cyc   = (cycles >= 0) ? sprintf("%.2f", cycles / iters) : "-"
			# cyc/acc를 접근 한 번당 ns로 나누면 대략적인 clock 주파수가 나온다.
			ghz   = (cycles >= 0 && ns > 0) ? sprintf("%.2f", (cycles / iters) / ns) : "-"

			printf "%8s  %s%3d%s  %9.3f  %14s  %8s  %8s  %8s  %8s  %8s  %8s\n",
			       size, dim, rep, reset, ns, commify(cycles), cyc, ghz,
			       pct(l1h, total), pct(l2h, total), pct(l3h, total), pct(dram, total)

			print size, ns, cyc, ghz, pct(l1h, total), pct(l2h, total),
			      pct(l3h, total), pct(dram, total) >> rows
		}
	'
}

printf "%s%8s  %3s  %9s  %14s  %8s  %8s  %8s  %8s  %8s  %8s%s\n" \
	"$BOLD" "size" "rep" "ns" "cycles" "cyc/acc" "GHz" "L1 hit%" "L2 hit%" "L3 hit%" "DRAM%" "$RESET"
printf "%s%s%s\n" "$DIM" "$(printf '─%.0s' $(seq 1 100))" "$RESET"

for pow in $(seq "$POW_MIN" "$POW_MAX"); do # 기본 4KB 32MB까지 테스트
	bytes=$((1 << pow))
	size=$(human "$bytes")

	for rep in $(seq 1 "$REPS"); do
		# taskset -c 를 통해서 core를 고정. perf 결과는 파일로 빼서 latency 출력과 섞이지 않게 한다.
		out=$(perf stat -o "$perf_out" -x, -e "$EVENTS" -- \
			taskset -c "$CORE" ./latency "$bytes" "$ITERS" 2>/dev/null)
		ns=${out#*,}

		print_row "$size" "$rep" "$ns" \
			"$(counter cycles)" "$ITERS" \
			"$(counter mem_load_uops_retired.l1_hit)" \
			"$(counter mem_load_uops_retired.l1_miss)" \
			"$(counter mem_load_uops_retired.l2_hit)" \
			"$(counter mem_load_uops_retired.l3_hit)" \
			"$(counter mem_load_uops_retired.dram_hit)" \
			"$rows"
	done
done

# 크기별 중간값 요약
printf "\n%s%s (크기당 %s회 중간값)%s\n" "$BOLD" "요약" "$REPS" "$RESET"
printf "%s%8s  %9s  %8s  %8s  %8s  %8s  %8s  %8s%s\n" \
	"$BOLD" "size" "ns" "cyc/acc" "GHz" "L1 hit%" "L2 hit%" "L3 hit%" "DRAM%" "$RESET"
printf "%s%s%s\n" "$DIM" "$(printf '─%.0s' $(seq 1 79))" "$RESET"

awk '
	function median(arr, n,   i, j, key, mid) {
		if (n == 0) return "-"
		for (i = 2; i <= n; i++) { # mawk에는 asort가 없어서 직접 정렬한다.
			key = arr[i]
			for (j = i - 1; j >= 1 && arr[j] > key; j--) arr[j + 1] = arr[j]
			arr[j + 1] = key
		}
		mid = int((n + 1) / 2)
		return (n % 2) ? arr[mid] : (arr[mid] + arr[mid + 1]) / 2
	}
	{
		size = $1
		if (!(size in seen)) { seen[size] = 1; order[++nsize] = size }
		i = ++count[size]
		for (col = 2; col <= 8; col++) v[size, col, i] = $col
	}
	END {
		for (s = 1; s <= nsize; s++) {
			size = order[s]; n = count[size]
			out = sprintf("%8s", size)
			for (col = 2; col <= 8; col++) {
				split("", tmp)
				m = 0
				for (i = 1; i <= n; i++)
					if (v[size, col, i] != "-") tmp[++m] = v[size, col, i] + 0
				med = median(tmp, m)
				if (med == "-")      out = out sprintf("  %8s", "-")
				else if (col == 2)   out = out sprintf("  %9.3f", med)
				else                 out = out sprintf("  %8.2f", med)
			}
			print out
		}
	}
' "$rows"
