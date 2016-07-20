TARGET = ./test

$(TARGET) : testqueue.c ../server/service-src/queue.c
	gcc -Wall -g -DDEBUG -fPIC -o $@ $^ -I../server/service-src/ -I./

clean :
	rm $(TARGET)