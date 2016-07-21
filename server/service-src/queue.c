#include "queue.h"
#include "skynet.h"
#include "string.h"
#include "assert.h"

void
queue_init(struct queue *q, int sz) {
	q->head = 0;
	q->tail = 0;
	q->sz = sz;
	q->cap = 4;
	q->buffer = skynet_malloc(q->cap * q->sz);
}

void
queue_exit(struct queue *q) {
	skynet_free(q->buffer);
	q->buffer = NULL;
}

int
queue_empty(struct queue *q) {
	return q->head == q->tail;
}

int
queue_pop(struct queue *q, void *result) {
	if (q->head == q->tail) {
		return 1;
	}
	memcpy(result, q->buffer + q->head * q->sz, q->sz);
	q->head++;
	if (q->head >= q->cap)
		q->head = 0;
	return 0;
}

void
queue_push(struct queue *q, const void *value) {
	void * slot = q->buffer + q->tail * q->sz;
	++q->tail;
	if (q->tail >= q->cap)
		q->tail = 0;
	if (q->head == q->tail) {
		// full
		assert(q->sz > 0);
		int cap = q->cap * 2;
		char * tmp = skynet_malloc(cap * q->sz);
		int i;
		int head = q->head;
		for (i=0;i<q->cap;i++) {
			memcpy(tmp + i * q->sz, q->buffer + head * q->sz, q->sz);
			++head;
			if (head >= q->cap) {
				head = 0;
			}
		}
		skynet_free(q->buffer);
		q->head = 0;
		slot = tmp + (q->cap-1) * q->sz;
		q->tail = q->cap;
		q->cap = cap;
		q->buffer = tmp;
	}
	memcpy(slot, value, q->sz);
}

int
queue_size(struct queue *q) {
	if (q->head > q->tail) {
		return q->tail + q->cap - q->head;
	}
	return q->tail - q->head;
}
