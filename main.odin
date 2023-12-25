// Based on 
// https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf
package main

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:testing"
import "core:reflect"
import "core:os"
import "core:bufio"
import "core:io"
import "core:math/rand"


// 2-3
Opcode :: enum {
    /// Move byte or word.
    RegOrMemToFromReg = 0b100010,
    ImmToRegOrMem = 0b1011,
}

// Selects register or memory mode with displacement length.
//
// Table 4-8. MOD (Mode) Field Encoding (4-20)
Mode :: enum {
    // Except when R/M = 110, then 16-bit displacement follows.
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

Error :: enum {
    None,
    UnsupportedOpcode,
}


op_str :: proc(opcode: Opcode) -> (string, Error) {
    op := opcode;
    if u8(op) & 0b101100 == 0b101100 {
        op = .ImmToRegOrMem
    }

    switch op {
        case .ImmToRegOrMem, .RegOrMemToFromReg:
            return "mov", .None
    }

    err_msg := fmt.tprint("Unsupported", opcode)

    return err_msg, .UnsupportedOpcode
}

sim :: proc() -> Error {
  context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})

  buf := make([]byte, 8)

  reg_str_w0 := RegisterStringW0;
  reg_str_w1 := RegisterStringW1;

  // fd, ferr := os.open("./listing_0038_many_register_mov");
  fd, ferr := os.open("./listing_0039_more_movs");
  if ferr != 0 {
      return .None
  }

  bytes, ok := os.read_entire_file(fd)

  if !ok {
      return .None
  }

  log.debugf("Read %d bytes.", len(bytes))

  out := make([dynamic]string)
  b := strings.Builder{}
  defer strings.builder_destroy(&b)

  ea := strings.Builder{}
  defer strings.builder_destroy(&ea)

  for i := 0; i < len(bytes); i += 2 {
    first := bytes[i]
    second := bytes[i + 1]

    opcode := Opcode(first >> 2)
    // Direction: To Register: From Register
    d := first & DIRECTION_MASK >> 1
    // Word/Byte Operation
    w := first & WORD_BYTE_OP_MASK 

    mode := Mode(second >> MOD_OFFSET) 
    regs := second & 0b111111

    op := op_str(opcode) or_return
    fmt.printf("[%i] d=%b, op=%s (%b)\n", i / 2, d, op, u8(opcode))
    res := make([dynamic]string)
    strings.write_string(&b, op)
    strings.write_string(&b, " ")

    reg := second & REG_MASK >> 3 
    src_operand := fmt.tprint(reg)
    dst_operand := fmt.tprint(reg)
    switch opcode {
        case .ImmToRegOrMem:
            return .None
        case .RegOrMemToFromReg:
            r_m := second & R_M_MASK 

            if mode == .Register {
                if w == 0 {
                    reg_1 := RegisterW0(reg)
                    reg_2 := RegisterW0(r_m)
                    src_operand = reg_str_w0[reg_2]
                    dst_operand = reg_str_w0[reg_1]
                } else if w == 1 {
                    reg_1 := RegisterW1(reg)
                    reg_2 := RegisterW1(r_m)
                    src_operand = reg_str_w1[reg_2]
                    dst_operand = reg_str_w1[reg_1]
                }

            } else {
                strings.write_string(&ea, "[")
                switch r_m {
                    case 0b000:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.BX])
                        strings.write_string(&ea, " + ")
                        strings.write_string(&ea, reg_str_w1[RegisterW1.SI])
                    case 0b001:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.BX])
                        strings.write_string(&ea, " + ")
                        strings.write_string(&ea, reg_str_w1[RegisterW1.DI])
                    case 0b010:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.BP])
                        strings.write_string(&ea, " + ")
                        strings.write_string(&ea, reg_str_w1[RegisterW1.SI])
                    case 0b011:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.BP])
                        strings.write_string(&ea, " + ")
                        strings.write_string(&ea, reg_str_w1[RegisterW1.DI])
                    case 0b100:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.SI])
                    case 0b101:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.DI])
                    case 0b110:
                        // TODO:eandle 110?
                        strings.write_string(&ea, reg_str_w1[RegisterW1.BP])
                    case 0b111:
                        strings.write_string(&ea, reg_str_w1[RegisterW1.BX])

                }
                    
                switch mode {
                    case .Memory8BitDisplacement:
                        displacement := bytes[i + 2]
                        if displacement != 0 {
                            strings.write_string(&ea, " + ")
                            strings.write_string(&ea, fmt.tprint(displacement))
                        }
                        i += 1
                    case .Memory16BitDisplacement:
                        third := bytes[i + 2]
                        fourth := bytes[i + 3]
                        displacement := u16(fourth) << 8 + u16(third)
                        if displacement != 0 {
                            strings.write_string(&ea, " + ")
                            strings.write_string(&ea, fmt.tprint(displacement))
                        }
                        i += 2 
                    case .MemoryNoDisplacement:
                        if r_m == 0b110 {
                            third := bytes[i + 2]
                            fourth := bytes[i + 3]
                            displacement := u16(fourth) << 8 + u16(third)
                            if displacement != 0 {
                                strings.write_string(&ea, " + ")
                                strings.write_string(&ea, fmt.tprint(displacement))
                            }
                            i += 2 
                        }
                    case .Register: 
                }


                strings.write_string(&ea, "]")
                src_operand = w == 0 ? reg_str_w0[RegisterW0(reg)] :
                              reg_str_w1[RegisterW1(reg)]


                dst_operand = fmt.tprint(strings.to_string(ea))
                if d == 0 {
                        src_operand, dst_operand = dst_operand, src_operand 
                }
            }
        case:
            // If no cases match, this might be a 8-bit imm to reg move.

            if u8(opcode) & 0b101100 == 0b101100 {

                w := u8(opcode) & 0b000010 >> 1
                if w == 0 {
                    reg := RegisterW0(u8(first) & 0b00000111)
                    src_operand = reg_str_w0[reg]
                    dst_operand = fmt.tprint(second)
                } else if w == 1 {
                    reg := RegisterW1(u8(first) & 0b00000111)
                    src_operand = reg_str_w1[reg]
                    third := bytes[i + 2]
                    data := u16(third) << 8 + u16(second)
                    dst_operand = fmt.tprint(data)
                    i += 1
                }
                
            } else {

                fmt.printf("Unknown opcode %b\n", u8(opcode))
                return .UnsupportedOpcode
            }
    }

    

    strings.write_string(&b, fmt.tprint(src_operand))
    strings.write_string(&b, ", ")
    strings.write_string(&b, fmt.tprint(dst_operand))
    strings.write_string(&b, "\n")
    strings.builder_reset(&ea)
  }

  fmt.println(strings.to_string(b))
  return .None
}

main :: proc() {
    res := sim()
}

