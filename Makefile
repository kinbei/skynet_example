SKYNET_PATH = ./skynet

.PHONY : skynet

all : \
	skynet \
	./server/cservice/package.so \
	./server/luaclib/zwproto.so

skynet : 
	cd skynet && $(MAKE) linux

./server/cservice/package.so : ./server/service-src/service_package.c ./server/service-src/queue.c
	gcc -Wall -g -DDEBUG --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/skynet-src

./server/luaclib/zwproto.so : ./server/lualib-src/zwproto.c
	gcc -Wall -g -DDEBUG --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/3rd/lua -I$(SKYNET_PATH)/lualib-src/sproto

clean : 
	cd skynet && $(MAKE) cleanall
	rm ./server/cservice/package.so
	rm ./server/luaclib/zwproto.so
