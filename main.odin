// Based on 
// https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf
package main

import "core:fmt"
import "core:testing"
import "core:reflect"
import "core:os"
import "core:bufio"
import "core:io"
import "core:math/rand"

// 2-3
Opcode :: enum {
    /// Move byte or word.
    MOV = 0b100010,
}

OpcodeString :: [Opcode]string {
    .MOV = "mov",
}

// Selects register or memory mode with displacement length.
//
// Table 4-8. MOD (Mode) Field Encoding (4-20)
Mode :: enum {
    MemoryNoDisplacement = 0b00,
    Memory8BitDisplacement = 0b01,
    Memory16BitDisplacement = 0b10,
    Register = 0b11,
}

RegisterW0 :: enum {
    AL = 0b000,
    CL = 0b001,
    DL = 0b010,
    BL = 0b011,
    AH = 0b100,
    CH = 0b101,
    DH = 0b110,
    BH = 0b111,
}

RegisterStringW0 :: [RegisterW0]string {
   .AL = "al",
   .CL = "cl",
   .DL = "dl",
   .BL = "bl",
   .AH = "ah",
   .CH = "ch",
   .DH = "dh",
   .BH = "bh",
}

RegisterW1 :: enum {
    AX = 0b000,
    CX = 0b001,
    DX = 0b010,
    BX = 0b011,
    SP = 0b100,
    BP = 0b101,
    SI = 0b110,
    DI = 0b111,
}

RegisterStringW1 :: [RegisterW1]string {
   .AX = "ax",
   .CX = "cx",
   .DX = "dx",
   .BX = "bx",
   .SP = "sp",
   .BP = "bp",
   .SI = "si",
   .DI = "di",
}

/* Masks */
DIRECTION_MASK : u8 = 0b0000_0010
WORD_BYTE_OP_MASK : u8 = 0b0000_0001
REG_MASK: u8 = 0b0011_1000
R_M_MASK: u8 = 0b0000_0111

/* Offsets */
MOD_OFFSET: u8 = 6

DEBUG :: #config(DEBUG, false)

main :: proc() {
  buf := make([]byte, 8)

  op_str := OpcodeString;
  reg_str_w0 := RegisterStringW0;
  reg_str_w1 := RegisterStringW1;

  fd, ferr := os.open("./listing_0038_many_register_mov");
  if ferr != 0 {
      return
  }

  bytes, ok := os.read_entire_file(fd)

  if !ok {
      return
  }

  when DEBUG {
     fmt.println("buflen: ", len(buf))
      fmt.printf("Read %d bytes.\n\n", len(bytes))
      fmt.println("*** BEGIN DECODE ***")
  } 
  for i := 0; i < len(bytes); i += 2 {

    first := bytes[i]
    second := bytes[i + 1]

    opcode := Opcode(first >> 2)
    // Direction: To Register: From Register
    d := first & DIRECTION_MASK
    // Word/Byte Operation
    w := first & WORD_BYTE_OP_MASK 

    mode := Mode(second >> MOD_OFFSET) 
    regs := second & 0b111111

    switch opcode {
        case .MOV:
            reg := second & REG_MASK >> 3 
            r_m := second & R_M_MASK 

            if w == 0 {
                reg_1 := RegisterW0(reg)
                reg_2 := RegisterW0(r_m)
                fmt.printf("%s %s, %s\n", op_str[opcode], reg_str_w0[reg_1], reg_str_w0[reg_2])
            } else if w == 1 {
                reg_1 := RegisterW1(reg)
                reg_2 := RegisterW1(r_m)
                fmt.printf("%s %s, %s\n", op_str[opcode], reg_str_w1[reg_1], reg_str_w1[reg_2])
            }
    }
  }
}

