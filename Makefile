
build:
	../Odin/odin build main.odin -file

run:
	../Odin/odin run main.odin -file -- ${listing}

run-all:
	../Odin/odin run main.odin -file

test-all:
	./test.sh

fmt:
	../odinfmt -w main.odin
