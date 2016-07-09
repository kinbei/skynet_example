SKYNET_PATH = ../skynet

all : \
	./cservice/package.so \
	./lualib/zwproto.so

./cservice/package.so : ./service-src/service_package.c ./service-src/queue.c
	gcc -Wall -g -DDEBUG --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/skynet-src

./lualib/zwproto.so : ./lualib-src/zwproto.c
	gcc -Wall -g -DDEBUG --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/3rd/lua -I$(SKYNET_PATH)/lualib-src/sproto

clean :
	rm ./cservice/package.so
	rm ./lualib/zwproto.so
