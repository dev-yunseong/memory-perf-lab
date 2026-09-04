# 측정 환경

- Intel(R) N100, core 4
- L1d 코어당 32KB, L1d 코어당 64KB, L2 2MB (공유), L3 6MB (공유) 
- 주파수 400MHz-3400MHz

## 예상
- 32KB 이하를 사용할 때는 L1d를 사용할 것이기에 매우 빠를 것
- 그 후 2MB, 6MB에 따라 느려질 것


## 명령어

```bash
$ lscpu # cpu 정보를 출력한다.

 CPU op-mode(s):            32-bit, 64-bit # CPU 명령어 모드
  Address sizes:             39 bits physical, 48 bits virtual # 주소 크기
  Byte Order:                Little Endian
CPU(s):                      4 # cpu 개수
  On-line CPU(s) list:       0-3 # cpu 번호
Vendor ID:                   GenuineIntel
  Model name:                Intel(R) N100 # cpu 모델명
    CPU family:              6
    Model:                   190
    Thread(s) per core:      1 # core 당 thread 개수
    Core(s) per socket:      4 # cpu 패키지 하나에 물리 코어 4개
    Socket(s):               1 # 
    Stepping:                0
    CPU(s) scaling MHz:      77% # 현재 주파수 / 최대 주파수
    CPU max MHz:             3400.0000
    CPU min MHz:             700.0000
    BogoMIPS:                1612.80
Virtualization features:
  Virtualization:            VT-x # 하드웨어 가상화 지원
Caches (sum of all):
  L1d:                       128 KiB (4 instances) # L1 data cache 코어마다 존재
  L1i:                       256 KiB (4 instances) # L1 instruction cache 코어마다 존재
  L2:                        2 MiB (1 instance) # L2 cache 4개의 코어가 공유함
  L3:                        6 MiB (1 instance) # L3 cache
NUMA:
  NUMA node(s):              1
  NUMA node0 CPU(s):         0-3
```


```bash
$ cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor # cpu 주파수 정책
─────┬───────────────────────────────────────────────────────────────────────
     │ File: /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
─────┼───────────────────────────────────────────────────────────────────────
   1 │ powersave
─────┴───────────────────────────────────────────────────────────────────────
─────┬───────────────────────────────────────────────────────────────────────
     │ File: /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
─────┼───────────────────────────────────────────────────────────────────────
   1 │ powersave
─────┴───────────────────────────────────────────────────────────────────────
─────┬───────────────────────────────────────────────────────────────────────
     │ File: /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
─────┼───────────────────────────────────────────────────────────────────────
   1 │ powersave
─────┴───────────────────────────────────────────────────────────────────────
─────┬───────────────────────────────────────────────────────────────────────
     │ File: /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
─────┼───────────────────────────────────────────────────────────────────────
   1 │ powersave
─────┴───────────────────────────────────────────────────────────────────────

```
