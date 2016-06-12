SKYNET_PATH = ../skynet
TARGET = ./cservice/package.so

$(TARGET) : service_package.c
	gcc -Wall -g --shared -fPIC -o $@ $^ -I$(SKYNET_PATH)/skynet-src

clean :
	rm $(TARGET)