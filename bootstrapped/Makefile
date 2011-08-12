parser: parse.c ../parse.c ../print.c
	gcc $^ -o $@

test: parser
	sh test.sh

clean:
	rm -f parser
