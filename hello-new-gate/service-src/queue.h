#ifndef queue_h
#define queue_h

#include <stdio.h>
#include <stdint.h>

struct queue {
	int cap;
	int sz;
	int head;
	int tail;
	char * buffer;
};

void queue_init(struct queue *q, int sz);
int queue_empty(struct queue *q);
int queue_pop(struct queue *q, void *result);
void queue_push(struct queue *q, const void *value);
int queue_size(struct queue *q);

#endif
