#include "skynet.h"
#include "skynet_socket.h"
#include "queue.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#define TIMEOUT "1000000"	// 10s

struct response {
	size_t sz;
	void * msg;
};

struct request {
	uint32_t source;
	int session;
};

#pragma pack(push, 1)
struct proto_header_t {
	uint32_t magic;
	uint8_t version;
	uint32_t serialno;
	uint32_t servantname;
	uint32_t checksum;
	uint16_t flag;
	uint8_t size[3]; // If size[0] < 0xFF then size[0] is the size of package; otherwise, size[1] x 0x100 + size[2] is the size of package
};
#pragma pack(pop)

// see also the comments of size field
#define PROTO_EXTRA_SIZE (sizeof(uint8_t) * 2)
#define PROTO_HEADER_SIZE ( sizeof(struct proto_header_t) - PROTO_EXTRA_SIZE )
#define LONG_PROTO_HEADER_SIZE sizeof(struct proto_header_t)

// must make sure the header is complete header else return value is wrong
static int 
get_size(struct proto_header_t *header) {
	if ( header->size[0] < 0xFF )
		return header->size[0];

	return header->size[1] * 0x100 + header->size[2];
}

struct package {
	uint32_t manager;
	int fd;
	
	int heartbeat;
	int recv;

	int init;
	int closed;

	int header_sz;
	struct proto_header_t header;

	int uncomplete_sz;
	struct response uncomplete;

	struct queue request;
	struct queue response;
};

static void
service_exit(struct skynet_context *ctx, struct package *P) {
	// report manager
	P->closed = 1;
	while (!queue_empty(&P->request)) {
		struct request req;
		queue_pop(&P->request, &req);
		skynet_send(ctx, 0, req.source, PTYPE_ERROR, req.session, NULL, 0);
	}
	while (!queue_empty(&P->response)) {
		// drop the message
		struct response resp;
		queue_pop(&P->response, &resp);
		skynet_free(resp.msg);
	}
	skynet_send(ctx, 0, P->manager, PTYPE_TEXT, 0, "CLOSED", 6);
	skynet_command(ctx, "EXIT", NULL);
}

static void
report_info(struct skynet_context *ctx, struct package *P, int session, uint32_t source) {
	int uncomplete;
	int uncomplete_sz;
	if (P->header_sz != 0) {
		uncomplete = -1;
		uncomplete_sz = 0;
	} else if (P->uncomplete_sz == 0) {
		uncomplete = 0;
		uncomplete_sz = 0;
	} else {
		uncomplete = P->uncomplete_sz;
		uncomplete_sz = P->uncomplete.sz;
	}
	char tmp[128];
	int n = sprintf(tmp,"req=%d resp=%d uncomplete=%d/%d", queue_size(&P->request), queue_size(&P->response), uncomplete, uncomplete_sz);
	skynet_send(ctx, 0, source, PTYPE_RESPONSE, session, tmp, n);
}

static void
command(struct skynet_context *ctx, struct package *P, int session, uint32_t source, const char *msg, size_t sz) {
	switch (msg[0]) {
	case 'R':
		// request a package
		if (P->closed) {
			skynet_send(ctx, 0, source, PTYPE_ERROR, session, NULL, 0);
			break;
		}
		if (!queue_empty(&P->response)) {
			assert(queue_empty(&P->request));
			struct response resp;
			queue_pop(&P->response, &resp);
			skynet_send(ctx, 0, source, PTYPE_RESPONSE, session, resp.msg, resp.sz);
		} else {
			struct request req;
			req.source = source;
			req.session = session;
			queue_push(&P->request, &req);
		}
		break;
	case 'K':
		// shutdown the connection
		skynet_socket_shutdown(ctx, P->fd);
		break;
	case 'I':
		report_info(ctx, P, session, source);
		break;
	default:
		// invalid command
		skynet_error(ctx, "Invalid command %.*s", (int)sz, msg);
		skynet_send(ctx, 0, source, PTYPE_ERROR, session, NULL, 0);
		break;
	};
}

// static void
// dump_hex(const uint8_t *msg, int sz) {
//	int i;
//	for (i = 0; i < sz; i++)
//		printf("%02X ", msg[i]);
//	printf("\n");
//	printf("----------------- \n");
// }

static void
new_message(struct package *P, const uint8_t *msg, int sz) {
	// dump_hex(msg, sz);

	++P->recv;

	for (;;) {
		
		// set P->uncomplete_sz zero in package_create()
		// and only change value in this function
		if (P->uncomplete_sz >= 0) {
			if (sz >= P->uncomplete_sz) {
				memcpy(P->uncomplete.msg + P->uncomplete.sz - P->uncomplete_sz, msg, P->uncomplete_sz);
				msg += P->uncomplete_sz;
				sz -= P->uncomplete_sz;
				queue_push(&P->response, &P->uncomplete);
				P->uncomplete_sz = -1;
			} else {
				memcpy(P->uncomplete.msg + P->uncomplete.sz - P->uncomplete_sz, msg, sz);
				P->uncomplete_sz -= sz;
				return;
			}
		}

		if (sz <= 0)
			return;

		// set P->header_sz zero in package_create()
		// and only change value in this function
		// P->header_sz is zero when P->header has no data
		if (P->header_sz == 0) {

			if ( sz < PROTO_HEADER_SIZE ) {
				memcpy( ((char*)&P->header) + P->header_sz, msg, sz );
				P->header_sz += sz;
				return;
			}
			else {
				memcpy( ((char*)&P->header) + P->header_sz, msg, PROTO_HEADER_SIZE );
				P->header_sz += PROTO_HEADER_SIZE;
				msg += PROTO_HEADER_SIZE;
				sz -= PROTO_HEADER_SIZE;

				if ( P->header.size[0] == 0xFF ) {
					if ( sz <= PROTO_EXTRA_SIZE ) {
						memcpy( ((char*)&P->header) + P->header_sz, msg, sz );
						P->header_sz += sz;
						return;
					}

					memcpy( ((char*)&P->header) + P->header_sz, msg, PROTO_EXTRA_SIZE );
					P->header_sz += PROTO_EXTRA_SIZE;
					msg += PROTO_EXTRA_SIZE;
					sz -= PROTO_EXTRA_SIZE;
				}
			}

		} else {
			assert( P->header_sz < PROTO_HEADER_SIZE || P->header_sz < LONG_PROTO_HEADER_SIZE );

			if ( sz < ( PROTO_HEADER_SIZE - P->header_sz) ) {
				memcpy( ((char*)&P->header) + P->header_sz, msg, sz );
				P->header_sz += sz;
				return;
			}
			else {
				memcpy( ((char*)&P->header) + P->header_sz, msg, ( PROTO_HEADER_SIZE - P->header_sz) );
				P->header_sz += ( PROTO_HEADER_SIZE - P->header_sz);
				msg += ( PROTO_HEADER_SIZE - P->header_sz);
				sz -= ( PROTO_HEADER_SIZE - P->header_sz);
				
				if ( P->header.size[0] == 0xFF ) {
					if ( sz <= PROTO_EXTRA_SIZE ) {
						memcpy( ((char*)&P->header) + P->header_sz, msg, sz );
						P->header_sz += sz;
						return;
					}

					memcpy( ((char*)&P->header) + P->header_sz, msg, PROTO_EXTRA_SIZE );
					P->header_sz += PROTO_EXTRA_SIZE;
					msg += PROTO_EXTRA_SIZE;
					sz -= PROTO_EXTRA_SIZE;
				}
			}
		}

		P->header_sz = 0;
		P->uncomplete.sz = get_size(&P->header) + sizeof(P->header);
		P->uncomplete.msg = skynet_malloc(P->uncomplete.sz);
		P->uncomplete_sz = P->uncomplete.sz;

		memcpy(P->uncomplete.msg + P->uncomplete.sz - P->uncomplete_sz, &P->header, sizeof(P->header));
		P->uncomplete_sz -= sizeof(P->header);
	}
}

static void
response(struct skynet_context *ctx, struct package *P) {
	while (!queue_empty(&P->request)) {
		if (queue_empty(&P->response)) {
			break;
		}
		struct request req;
		struct response resp;
		queue_pop(&P->request, &req);
		queue_pop(&P->response, &resp);
		skynet_send(ctx, 0, req.source, PTYPE_RESPONSE, req.session, resp.msg, resp.sz);
	}
}

static void
socket_message(struct skynet_context *ctx, struct package *P, const struct skynet_socket_message * smsg) {
	switch (smsg->type) {
	case SKYNET_SOCKET_TYPE_CONNECT:
		if (P->init == 0 && smsg->id == P->fd) {
			skynet_send(ctx, 0, P->manager, PTYPE_TEXT, 0, "SUCC", 4);
			P->init = 1;
		}
		break;
	case SKYNET_SOCKET_TYPE_CLOSE:
	case SKYNET_SOCKET_TYPE_ERROR:
		if (P->init == 0 && smsg->id == P->fd) {
			skynet_send(ctx, 0, P->manager, PTYPE_TEXT, 0, "FAIL", 4);
			P->init = 1;
		}
		if (smsg->id != P->fd) {
			skynet_error(ctx, "Invalid fd (%d), should be (%d)", smsg->id, P->fd);
		} else {
			if (smsg->type == SKYNET_SOCKET_TYPE_ERROR) {
				skynet_error(ctx, "Socket error fd(%d)", smsg->id);
			}
			response(ctx, P);
			service_exit(ctx, P);
		}
		break;
	case SKYNET_SOCKET_TYPE_DATA:
		new_message(P, (const uint8_t *)smsg->buffer, smsg->ud);
		skynet_free(smsg->buffer);
		response(ctx, P);
		break;
	case SKYNET_SOCKET_TYPE_WARNING:
		skynet_error(ctx, "Overload on %d", P->fd);
		break;
	default:
		// ignore
		break;
	}
}

static void
heartbeat(struct skynet_context *ctx, struct package *P) {
	// it will change P->recv value when recv socket data
	if (P->recv == P->heartbeat) {
		if (!P->closed) {
			skynet_socket_shutdown(ctx, P->fd);
			skynet_error(ctx, "timeout %d", P->fd);
		}
	} else {
		P->heartbeat = P->recv = 0;
		skynet_command(ctx, "TIMEOUT", TIMEOUT);
	}
}

static void
send_out(struct skynet_context *ctx, struct package *P, const void *msg, size_t sz) {
	if (sz > 0xffff) {
		skynet_error(ctx, "package too long (%08x)", (uint32_t)sz);
		return;
	}
	uint8_t *p = skynet_malloc(sz);
	memcpy(p, msg, sz);
	skynet_socket_send(ctx, P->fd, p, sz);
}

static int
message_handler(struct skynet_context * ctx, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct package *P = ud;
	switch (type) {
	case PTYPE_TEXT:
		command(ctx, P, session, source, msg, sz);
		break;
	case PTYPE_CLIENT:
		send_out(ctx, P, msg, sz);
		break;
	case PTYPE_RESPONSE:
		// It's timer
		// timer in skynet will send PTYPE_RESPONSE message, see also skynet_timer.c - skynet_timeout()
		heartbeat(ctx, P);
		break;
	case PTYPE_SOCKET:
		socket_message(ctx, P, msg);
		break;
	case PTYPE_ERROR:
		// ignore error
		break;
	default:
		if (session > 0) {
			// unsupport type, raise error
			skynet_send(ctx, 0, source, PTYPE_ERROR, session, NULL, 0);
		}
		break;
	}
	return 0;
}

struct package *
package_create(void) {
	struct package * P = skynet_malloc(sizeof(*P));
	memset(P, 0, sizeof(*P));
	// heartbeat() will be call in package_init() function, so set P->heartbeat = -1 for not to close connection of client
	P->heartbeat = -1;
	P->uncomplete_sz = -1;
	queue_init(&P->request, sizeof(struct request));
	queue_init(&P->response, sizeof(struct response));
	return P;
}

void
package_release(struct package *P) {
	skynet_free(P);
}

int
package_init(struct package * P, struct skynet_context *ctx, const char * param) {
	int n = sscanf(param ? param : "", "%u %d", &P->manager, &P->fd);
	if (n != 2 || P->manager == 0 || P->fd == 0) {
		skynet_error(ctx, "Invalid param [%s]", param);
		return 1;
	}
	skynet_socket_start(ctx, P->fd);
	skynet_socket_nodelay(ctx, P->fd);
	heartbeat(ctx, P);
	skynet_callback(ctx, P, message_handler);

	return 0;
}
