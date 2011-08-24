interpreter: interpreter.c parse.o print.o
	gcc $^ -o $@

parse.o: parse.c
	gcc -c $^ -o $@

print.o: print.c
	gcc -c $^ -o $@

test: interpreter state_diff
	sh test.sh

state_diff: state_diff.c parse.o
	gcc $^ -o $@

clean:
	rm -f interpreter *.o
