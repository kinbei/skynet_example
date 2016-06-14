SKYNET_PATH = ../skynet
TARGET = ./cservice/package.so

$(TARGET) : ./service-src/service_package.c ./service-src/queue.c
	gcc -Wall -g --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/skynet-src

clean :
	rm $(TARGET)
