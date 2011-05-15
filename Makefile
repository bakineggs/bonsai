interpreter: interpreter.c parse.o print.o
	gcc $^ -o $@

parse.o: parse.c
	gcc -c $^ -o $@

print.o: print.c
	gcc -c $^ -o $@

test: interpreter
	sh test.sh

clean:
	rm -f interpreter *.o
