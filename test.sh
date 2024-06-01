#!/bin/sh

OUT_DIR=./bin/actual/
EXPECTED_DIR=./bin/expected/
BINS=()

listing_num=$1

test_all () {
# 1) Disassemble the expected binaries with our simulator.
# These binaries are copied from cmuratori's repository.
../Odin/odin run main.odin -file

# 2) Re-compile all disassembled asm source files. 
for file in ./asm/actual/*.asm
do
    BIN_OUT_NAME=$(echo ${file} | cut -d '/' -f 4 | cut -d . -f 1)
    BIN_OUT_PATH=${OUT_DIR}${BIN_OUT_NAME}
    echo "Compiling: nasm ${file} -o ${BIN_OUT_PATH}"
    rm -f ${BIN_OUT_PATH}
    nasm ${file} -o ${BIN_OUT_PATH}
    BINS+=(${BIN_OUT_NAME})
    echo ${BINS}
done

num_tested=0
num_failed=0

printf "Running tests...\n"

passed=()
# 3) Compare the actual binaries with the expected binaries.
for bin in ${BINS[@]}; do
    actual=${OUT_DIR}${bin}
    expected=${EXPECTED_DIR}${bin}
    res=$(diff ${actual} ${expected})

    
    if [ ! -z "${res}" ]; then
        echo "- ${bin}\n  Failed; binaries mismatch"
        num_failed=$(expr $num_failed + 1)
    else
        passed+=(${bin})

    fi

    num_tested=$(expr $num_tested + 1)
done

num_passed=$(expr $num_tested - $num_failed)
printf "${num_passed} out of ${num_tested} listings passed.\n"

for bin in ${passed[@]}
do
    printf "${bin}\n"
done
}


test_one() {
    listing_asm=$(find asm/actual -name "*$listing_num*.asm")

    if [ "$listing_asm" == "" ]; then
        echo "Could not find listing '$listing_num'. Is it a valid listing number?"
        exit 1
    fi

    BIN_OUT_NAME=$(echo ${listing_asm} | cut -d '/' -f 3 | cut -d . -f 1)
    BIN_OUT_PATH=${OUT_DIR}${BIN_OUT_NAME}
    expected=${EXPECTED_DIR}${BIN_OUT_NAME}
    echo "Compiling: nasm ${listing_asm} -o ${BIN_OUT_PATH}"
    rm -f ${BIN_OUT_PATH}
    nasm ${listing_asm} -o ${BIN_OUT_PATH}

    res=$(diff ${expected} ${BIN_OUT_PATH})
    if [ ! -z "${res}" ]; then
        echo "- listing ${listing_num}:\n  Failed; binaries mismatch"
    fi


}

if [ "$listing_num" == "" ]; then
    test_all
else
    test_one
fi
exit 0
