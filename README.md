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


## 주파수 고정

처음 잰 결과는 계단이 울퉁불퉁했다.
원인을 찾다 보니 측정하는 동안 CPU 주파수가 계속 흔들리고 있었다.
클럭이 흔들리면 같은 크기를 재도 ns가 같이 흔들리기에 주파수를 고정하고 다시 쟀다.
고정하기 전에 잰 결과는 아래 메모리 실험 결과에 그대로 남겨두었다.

[실험 결과 csv](./results/median-service-on-800mhz.csv)

`no_turbo`로 설정하고 clock을 800MHz에 고정한 뒤 `run-with-perf.sh`로 4KB부터 32MB까지 크기당 5회 측정했다.

### 결과

각 크기당 5번 반복 측정했을 때의 중간값

```
            ns   cyc/acc   L1 hit%   L2 hit%   L3 hit%     DRAM%
  4KB    6.412      5.01     99.99      0.01      0.00      0.00
  8KB    6.418      5.01     99.98      0.02      0.00      0.00
 16KB    6.428      5.03     99.91      0.09      0.00      0.00
 32KB    6.491      5.07     99.66      0.33      0.00      0.00
 64KB   28.360     22.12      0.01     99.97      0.00      0.01
128KB   28.367     22.14      0.05     99.87      0.00      0.01
256KB   31.463     24.42      0.08     99.87      0.00      0.02
512KB   36.187     28.23      0.17     99.41      0.41      0.05
  1MB   42.142     32.81      0.28     94.74      4.82      0.11
  2MB   79.620     61.50      0.51     50.73     47.95      0.22
  4MB  114.193     88.45      1.05     17.98     74.82      5.44
  8MB  164.998    127.95      1.59     10.23     51.17     36.18
 16MB  229.746    178.31      3.08      5.55     23.66     66.85
 32MB  262.613    204.73      5.78      2.90     11.54     78.83
```

ns 자체는 앞의 측정보다 4배쯤 크다. 800MHz에서는 clock 하나가 1.25ns라서 그렇다.
그래서 절대값을 앞의 결과와 직접 비교하면 안 되고 계단의 모양을 봐야 한다.

같은 크기를 5번 반복했을 때의 편차가 눈에 띄게 줄었다.

```
         주파수 고정 전       800MHz 고정
              min      max     폭       min      max     폭
    4KB     1.774    1.779    0.3%     6.405    6.420    0.2%
    8KB     1.773    1.783    0.6%     6.411    6.700    4.5%
   16KB     1.776    1.783    0.4%     6.426    6.434    0.1%
   32KB     1.903    1.967    3.4%     6.487    6.499    0.2%
   64KB     6.796    7.840   15.4%    28.333   28.808    1.7%
  128KB     6.800    9.162   34.7%    28.316   28.876    2.0%
  256KB     8.096    8.136    0.5%    31.306   31.701    1.3%
  512KB     8.800    9.074    3.1%    35.961   36.639    1.9%
    1MB     9.207   10.896   18.3%    41.525   45.399    9.3%
    2MB    13.733   14.191    3.3%    79.124   80.813    2.1%
    4MB    24.678   26.284    6.5%   113.473  117.052    3.2%
    8MB    51.135   52.008    1.7%   164.802  165.742    0.6%
   16MB    97.798   99.086    1.3%   228.819  232.409    1.6%
   32MB   119.042  119.631    0.5%   262.003  268.590    2.5%
   64MB   130.353  130.470    0.1%  -
```

## 메모리 실험 결과

주파수를 고정하기 전에 잰 결과다.

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
| [`results/sweep-service-on-800mhz.csv`](./results/sweep-service-on-800mhz.csv) | 800MHz 고정, 4KB~32MB, 크기당 5회 raw 측정값 (perf counter 포함) |
| [`results/median-service-on-800mhz.csv`](./results/median-service-on-800mhz.csv) | 800MHz 고정 측정의 크기별 중간값 |
| [`results/perf-counters.txt`](./results/perf-counters.txt) | `perf stat` PMU counter 원본 출력 |
