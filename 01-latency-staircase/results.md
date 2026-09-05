## 메모리 실험 결과
[실험 결과 csv](./results/median-service-off.csv)

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

