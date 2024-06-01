# sim8086
8086 CPU simulator implementation in Odin. The implementation is based on the [Intel 8086 Family User's Manual](https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf).

A work-in-progress following the [Performance-Aware Programming Series](https://www.computerenhance.com/p/welcome-to-the-performance-aware).

# Prerequisites

- Odin
- nasm

# Test

Testing is done by disassembling compiled Assembly listings, re-assembling the result and doing a diff on
the expected and actual output binaries.

To test all listings:

```sh
$ ./test.sh
```

To test a specific listing, eg. listing 38:

```sh
$ ./test.sh 37
```
