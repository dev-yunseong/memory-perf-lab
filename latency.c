#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#define LINE 64

static double now_ns() {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main(int argc, char ** argv) {
	if (argc != 3) {
		fprintf(stderr, "usage: %s <bytes> <iterations>\n", argv[0]);
	}

	// 인자 파싱
	size_t bytes = strtoull(argv[1], NULL, 10);
	long iters = strtol(argv[2], NULL, 10);
	size_t nslots = bytes / LINE;
	if (nslots < 2) { fprintf(stderr, "too small\n"); return 1; }


	// 메모리 할당 (cache를 한번에 들고 올 때 64byte 단위로 들고 오기에 주소를 64의 배수가 되도록 메모리를 할당)
	char *buf = aligned_alloc(LINE, nslots * LINE);
	size_t *perm = malloc(nslots * sizeof(size_t));
	if (!buf || !perm) { fprintf(stderr, "alloc failed\n"); return 1;}

	for (size_t i = 0; i < nslots; i++) perm[i] = i;

	// 랜덤하게 perm 배열의 수를 섞는다.
	srand(42);
	for (size_t i = nslots - 1; i > 0; i--) {
		size_t j = (size_t)((double)rand() / ((double)RAND_MAX + 1.0) * (double)(i + 1));
		size_t t = perm[i]; perm[i] = perm[j]; perm[j] = t;
	}

	// buf에 perm 값을 저장한다.
    	for (size_t i = 0; i < nslots; i++)
        	*(size_t *)(buf + perm[i] * LINE) = perm[(i + 1) % nslots];

    	// buf를 perm 순서대로 순회하며 cache에 올린다.
    	size_t idx = 0;
    	for (size_t r = 0; r < 2; r++)
        	for (size_t i = 0; i < nslots; i++)
            		idx = *(size_t *)(buf + idx * LINE);

	// iters 만큼 cache를 순회하는 시간을 잰다.
    	double t0 = now_ns();
    	for (long i = 0; i < iters; i++)
        	idx = *(size_t *)(buf + idx * LINE);
    	double t1 = now_ns();


	// idx를 써야 컴파일러가 루프를 지우지 않는다.
    	fprintf(stderr, "sink=%zu\n", idx);
    	printf("%zu,%.3f\n", bytes, (t1 - t0) / (double)iters);

    	free(perm);
    	free(buf);
    	return 0;
}
