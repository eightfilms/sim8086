#!/bin/sh

../Odin/odin run main.odin -file

for file in ./listings/out/*.asm
do
    BIN_OUT=$(echo ${file} | cut -d . -f 2)
    echo "Compiling: nasm ${file} -o .${BIN_OUT}"
    rm -f ${BIN_OUT}
    nasm ${file} -o .${BIN_OUT}
done

expected_bins=$(find ./listings -maxdepth 1 -type f ! -name "*.asm")

num_tested=0
num_failed=0

printf "Running tests...\n"

# Loop through the found files and run your command
for bin in $expected_bins; do
    # Replace the following command with the one you want to run on each file
    listing_name=$(echo ${bin} | rev | cut -d '/' -f 1 | rev)
    actual_bin="./listings/out/${listing_name}"
    echo "- ${listing_name}"
    res=$(diff ${actual_bin} ${bin})

    
    if [ ! -z "${res}" ]; then
        printf "  Failed; binaries mismatch\n"
        num_failed=$(expr $num_failed + 1)
    fi

    num_tested=$(expr $num_tested + 1)
done

num_passed=$(expr $num_tested - $num_failed)
printf "${num_passed} out of ${num_tested} listings passed."

