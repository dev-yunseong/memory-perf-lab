# memory-perf-lab

접근하는 메모리 크기를 4KB부터 64MB까지 늘려가며 pointer chasing 지연 시간을 재고,
L1d / L2 / L3 / DRAM 경계에서 나타나는 계단을 관찰하는 실험이다.

## 실행 방법

```bash
gcc -O2 -o latency latency.c   # 빌드
./run.sh > results/sweep.csv   # 4KB~64MB, 크기당 5회 측정
```

`run.sh`는 `taskset -c "$CORE"`로 core를 고정한 뒤 `./latency <bytes> <iterations>`를 반복 호출한다.
`CORE`, `REPS`, `ITERS` 환경 변수로 조정할 수 있다.

## 측정 환경

Intel(R) N100 (core 4), L1d 코어당 32KB, L2 2MB 공유, L3 6MB 공유.
자세한 사양과 `lscpu` / `scaling_governor` 출력은 [environment.md](./environment.md)에 정리했다.

## 메모리 실험 결과

[실험 결과 csv](./results/median-service-on.csv)

각 크기당 5번 반복 층정했을 때의 중간값

```
4KB:    1.778ns
8KB:    1.774ns
16KB:   1.779ns
32KB:   1.920ns
64KB:   6.800ns
128KB:  6.803ns
256KB:  8.127ns
512KB:  8.816ns
1MB:    10.146ns
2MB:    13.853ns
4MB:    25.786ns
8MB:    51.686ns
16MB:   98.729ns
32MB:   119.166ns
64MB:   130.421ns
```

계단은 32KB-64KB, 2MB-4MB, 4MB-16MB에서 나타나는 것을 볼 수 있다.

L1d는   약 1.7ns
L2는    약 6.8ns
L3는    약 25.7ns
DRAM은  약 130.4ns인것을 볼 수 있다.

하지만 각 접근할 크기를 늘린다고 해서 모든 요청이 L1 cache에 가거나 DRAM에 가는 것이 아니기에 계단이 깔끔하게 보이지는 않았다.

## perf 결과

[실험 결과 file](./results/perf-counters.txt)

16KB, 1MB, 4MB, 32MB에서 측정을 진행했다.
L1-dcache-misses를 지원하지 않아서 L1에서의 cache miss를 정확히 알 수 없었다.

[cache-reference, cache-misses 관련 글](https://stackoverflow.com/questions/55035313/how-does-linux-perf-calculate-the-cache-references-and-cache-misses-events)에서 볼 수 있듯 cache-reference, cache-misses는 LLC 즉 L3 cache관련 통계이다. cache-reference는 loads, stores를 포함한 L3 cache에 접근한 횟수이다.

또한 [mem-load 관련 글](https://stackoverflow.com/questions/44466697/perf-stat-does-not-count-memory-loads-but-counts-memory-stores)에서 볼 수 있는 mem-loads가 0으로 고정되는 것은 intel cpu의 모니터링 방식의 문제이다.

general하게 perf에서 제공하는 키워드가 아닌 [intel cpu의 PMU event 명](https://perfmon-events.intel.com/index.html?evnt=ASSISTS.FP&pltfrm=ahybrid.html)을 찾아서 측정했다.

### 명령어

```bash
for bytes in 16384 1048576 4194304 33554432; do
  echo "=== ${bytes} bytes ==="

  perf stat -e \
    mem_load_uops_retired.l1_hit,\
    mem_load_uops_retired.l1_miss,\
    mem_load_uops_retired.l2_hit,\
    mem_load_uops_retired.l2_miss,\
    mem_load_uops_retired.l3_hit,\
    mem_load_uops_retired_misc.l3_miss,\
    mem_load_uops_retired.dram_hit \
        -- taskset -c 3 ./latency "$bytes" 20000000

done 2>&1 | tee results/perf-counters.txt
```

### 결과

접근하는 크기가 커질 수록 L1 -> L2 -> L3 -> DRAM까지 내려가는 것을 확인할 수 있다.

```
16KB
L1 hit: 121,776,787
L1 miss: 13,225
L2 hit: 8,109
L2 miss: 605
L3 hit: 388
L3 miss: 192
DRAM hit: 165
latency: 2.053 ns

1MB
L1 hit: 100,568,120
L1 miss: 20,035,090
L2 hit: 19,556,488
L2 miss: 360,230
L3 hit: 331,248
L3 miss: 7,977
DRAM hit: 6,441
latency: 9.522 ns

4MB
L1 hit: 103,455,530
L1 miss: 20,162,406
L2 hit: 3,428,994
L2 miss: 16,837,235
L3 hit: 15,933,822
L3 miss: 835,543
DRAM hit: 837,751
latency: 24.180 ns

32MB
L1 hit: 131,973,941
L1 miss: 21,880,422
L2 hit: 994,816
L2 miss: 20,507,724
L3 hit: 2,887,535
L3 miss: 17,595,779
DRAM hit: 17,603,270
latency: 120.154 ns
```

## 원본 데이터

| 파일 | 내용 |
| --- | --- |
| [`results/sweep-service-on.csv`](./results/sweep-service-on.csv) | 4KB~64MB, 크기당 5회 raw 측정값 |
| [`results/median-service-on.csv`](./results/median-service-on.csv) | 크기별 중간값 |
| [`results/perf-counters.txt`](./results/perf-counters.txt) | `perf stat` PMU counter 원본 출력 |
