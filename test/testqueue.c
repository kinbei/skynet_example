#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include <queue.h>

struct response {
	size_t sz;
	void * msg;
};

void test_queue_init() {
	struct queue qresp;

	queue_init(&qresp, sizeof(struct response));
	assert( queue_size(&qresp) == 0 );
	assert( qresp.sz == sizeof(struct response) );
	assert( qresp.head == 0 );
	assert( qresp.head == qresp.tail ) ;
	assert( qresp.buffer == NULL );
	assert( queue_empty(&qresp) == 1 );
}

void test_queue_push() {
	struct queue qresp;
	queue_init(&qresp, sizeof(struct response));

	struct response r1;
	r1.msg = malloc(10);
	r1.sz = 10;
	queue_push(&qresp, &r1);

	assert( queue_size(&qresp) == 1 );
	assert( queue_empty(&qresp) == 0 );

	struct response r2;
	queue_pop(&qresp, &r2);
	assert( r2.msg == r1.msg );
	assert( r2.sz == r2.sz );
	free( r1.msg );

	assert( queue_size(&qresp) == 0 );
	assert( queue_empty(&qresp) == 1 );
}

int main() {
	test_queue_init();
	test_queue_push();

	return 0;
}