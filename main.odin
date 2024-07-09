// Based on 
// https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf
package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:log"
import "core:math/rand"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"
import "core:testing"


// 2-3
Opcode :: enum {
	/// Move byte or word.
	RegOrMemToFromReg = 0b100010,
	ImmToRegOrMem     = 0b110001,
	/// Accumulator to memory (and vice versa) opcodes are both 101000,
	/// but the next bit determines direction.
	/// 1010000w == memory to acc
	/// 1010001w == acc to memory
	Accumulator       = 0b101000,
}

// Selects register or memory mode with displacement length.
//
// Table 4-8. MOD (Mode) Field Encoding (4-20)
Mode :: enum {
	// Except when R/M = 110, then 16-bit displacement follows.
	MemoryNoDisplacement    = 0b00,
	Memory8BitDisplacement  = 0b01,
	Memory16BitDisplacement = 0b10,
	Register                = 0b11,
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


DEBUG :: #config(DEBUG, false)

Error :: enum {
	None,
	UnsupportedOpcode,
}


op_str :: proc(opcode: Opcode) -> (string, Error) {
	op := opcode
	log.debugf("raw op=%s (%b)", opcode, u8(opcode))
	if u8(op) & 0b101100 == 0b101100 {
		op = .ImmToRegOrMem
	}

	switch op {
	case .ImmToRegOrMem, .RegOrMemToFromReg, .Accumulator:
		return "mov", .None
	}

	err_msg := fmt.tprint("Unsupported", opcode)

	return err_msg, .UnsupportedOpcode
}

/// The first byte of an 8086 instruction comes in this format:
/// 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7
///         opcode        | d | w 
decode_first_byte :: proc(first: byte) -> (opcode: Opcode, d, w: u8) {
	DIRECTION_MASK: u8 = 0b0000_0010
	IS_WORD_MASK: u8 = 0b0000_0001
	opcode = Opcode(first >> 2)
	// Direction: To Register: From Register
	d = first & DIRECTION_MASK >> 1
	// Word/Byte Operation
	w = first & IS_WORD_MASK

	return opcode, d, w
}

/// The second byte of an 8086 instruction comes in this format:
/// 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7
///  mode |    reg    |    r_m 
decode_second_byte :: proc(second: byte) -> (mod: Mode, reg, r_m: u8) {
	REG_MASK: u8 = 0b0011_1000
	R_M_MASK: u8 = 0b0000_0111

	/* Offsets */
	MOD_OFFSET: u8 = 6

	mod = Mode(second >> MOD_OFFSET)
	reg = second & REG_MASK >> 3
	r_m = second & R_M_MASK

	return mod, reg, r_m
}

sim :: proc(bytes: []byte) -> (out: string, err: Error) {
	using strings
	reg_str_w0 := RegisterStringW0
	reg_str_w1 := RegisterStringW1

	b := builder_make()

	ea := Builder{}
	defer builder_destroy(&ea)

	for i := 0; i < len(bytes); i += 2 {
		first, second := bytes[i], bytes[i + 1]
		opcode, d, w := decode_first_byte(first)
		mode, reg, r_m := decode_second_byte(second)

		op := op_str(opcode) or_return

		log.debugf("[%i] d=%b, op=%s (%b)", i / 2, d, op, u8(opcode))
		fmt.printf("reg = {} {:b}", reg, reg)
		src_operand, dst_operand := fmt.tprint(reg), fmt.tprint(reg)

		switch opcode {
		case .ImmToRegOrMem:
			if d == 1 {
				displacement: i16 = 0
				switch mode {
				case .Memory8BitDisplacement:
					displacement = i16(bytes[i + 3]) << 8 + i16(bytes[i + 2])
					data := i8(bytes[i + 4])
					defer i += 3
					dst_operand = w == 0 ? fmt.tprint("byte", data) : fmt.tprint("word", data)
				case .Memory16BitDisplacement:
					displacement = i16(bytes[i + 3]) << 8 + i16(bytes[i + 2])
					data := i16(bytes[i + 5]) << 8 + i16(bytes[i + 4])
					defer i += 4
					dst_operand = w == 0 ? fmt.tprint("byte", data) : fmt.tprint("word", data)
				case .MemoryNoDisplacement:
					data := i8(bytes[i + 2])
					defer i += 1
					dst_operand = w == 0 ? fmt.tprint("byte", data) : fmt.tprint("word", data)
				case .Register:
				}

				write_string(&ea, "[")
				switch r_m {
				case 0b000:
					write_string(&ea, reg_str_w1[RegisterW1.BX])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.SI])
				case 0b001:
					write_string(&ea, reg_str_w1[RegisterW1.BX])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.DI])
				case 0b010:
					write_string(&ea, reg_str_w1[RegisterW1.BP])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.SI])
				case 0b011:
					write_string(&ea, reg_str_w1[RegisterW1.BP])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.DI])
				case 0b100:
					write_string(&ea, reg_str_w1[RegisterW1.SI])
				case 0b101:
					write_string(&ea, reg_str_w1[RegisterW1.DI])
					if displacement > 0 {
						write_string(&ea, " + ")
						write_string(&ea, fmt.tprint(displacement))
					}
				case 0b110:
					write_string(&ea, reg_str_w1[RegisterW1.BP])
				case 0b111:
					write_string(&ea, reg_str_w1[RegisterW1.BX])

				}

				write_string(&ea, "]")
				src_operand = fmt.tprint(to_string(ea))

			}
		case .RegOrMemToFromReg:
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
				write_string(&ea, "[")
				switch r_m {
				case 0b000:
					write_string(&ea, reg_str_w1[RegisterW1.BX])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.SI])
				case 0b001:
					write_string(&ea, reg_str_w1[RegisterW1.BX])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.DI])
				case 0b010:
					write_string(&ea, reg_str_w1[RegisterW1.BP])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.SI])
				case 0b011:
					write_string(&ea, reg_str_w1[RegisterW1.BP])
					write_string(&ea, " + ")
					write_string(&ea, reg_str_w1[RegisterW1.DI])
				case 0b100:
					write_string(&ea, reg_str_w1[RegisterW1.SI])
				case 0b101:
					write_string(&ea, reg_str_w1[RegisterW1.DI])
				case 0b110:
					if mode != .MemoryNoDisplacement {
						write_string(&ea, reg_str_w1[RegisterW1.BP])
					}
				case 0b111:
					write_string(&ea, reg_str_w1[RegisterW1.BX])

				}

				switch mode {
				case .Memory8BitDisplacement:
					displacement := i8(bytes[i + 2])
					defer i += 1

					if displacement > 0 {
						write_string(&ea, " + ")
						write_string(&ea, fmt.tprint(displacement))
					} else if displacement < 0 {
						write_string(&ea, " - ")
						write_string(&ea, fmt.tprint(-displacement))
					} else {}


				case .Memory16BitDisplacement:
					third := bytes[i + 2]
					fourth := bytes[i + 3]
					defer i += 2

					displacement := i16(fourth) << 8 + i16(third)
					if displacement > 0 {
						write_string(&ea, " + ")
						write_string(&ea, fmt.tprint(displacement))
					} else if displacement < 0 {
						write_string(&ea, " - ")
						write_string(&ea, fmt.tprint(-displacement))
					} else {}

				case .MemoryNoDisplacement:
					if r_m == 0b110 {
						third := bytes[i + 2]
						fourth := bytes[i + 3]
						defer i += 2

						displacement := u16(fourth) << 8 + u16(third)
						if displacement != 0 {
							write_string(&ea, fmt.tprint(displacement))
						}
					}
				case .Register:
				}


				write_string(&ea, "]")
				src_operand =
					w == 0 ? reg_str_w0[RegisterW0(reg)] : reg_str_w1[RegisterW1(reg)]


				dst_operand = fmt.tprint(to_string(ea))
				if d == 0 {
					src_operand, dst_operand = dst_operand, src_operand
				}
			}
		case .Accumulator:
			b := Builder{}
			defer builder_destroy(&b)
			third := bytes[i + 2]

			mem_to_acc := d == 0
			addr := i16(third) << 8 + i16(second)
			write_string(&b, "[")
			write_string(&b, fmt.tprint(addr))
			write_string(&b, "]")
			if mem_to_acc {
				src_operand = "ax"
				dst_operand = fmt.tprint(to_string(b))
			} else {
				src_operand = fmt.tprint(to_string(b))
				dst_operand = "ax"
			}

			i += 1
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
				return "", .UnsupportedOpcode
			}
		}


		log.debugf(
			"op: %s %s %s",
			op,
			fmt.tprint(src_operand),
			fmt.tprint(dst_operand),
		)
		write_string(&b, op)
		write_string(&b, " ")
		write_string(&b, fmt.tprint(src_operand))
		write_string(&b, ", ")
		write_string(&b, fmt.tprint(dst_operand))
		write_string(&b, "\n")
		builder_reset(&ea)
	}

	log.debugf("Disassembly done!")
	return to_string(b), .None
}

main :: proc() {
	dir, _ := os.open("./bin/expected")

	actual_dir := filepath.join(
		[]string{os.get_current_directory(), "asm", "actual"},
	)
	os.make_directory(actual_dir)
	context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})


	info, _ := os.read_dir(dir, -1)
	if len(os.args) == 1 {
		for file in info {
			if !strings.has_suffix(file.name, ".asm") && !file.is_dir {
				code, _ := os.read_entire_file(file.fullpath)
				log.infof("Disassembling %s", file.name)
				log.debugf("Read %d bytes.", len(code))
				out, _ := sim(code)
				out_file := strings.join(
					[]string{filepath.join([]string{actual_dir, file.name}), ".asm"},
					"",
				)
				os.write_entire_file(out_file, transmute([]byte)out)
				log.infof("Wrote %d bytes to %s", len(out), out_file)
				delete(out)
			}
		}

	} else if len(os.args) == 2 {
		found := false

		listing_no := strings.concatenate({"listing_00", os.args[1]})
		for file in info {
			if strings.has_prefix(file.name, listing_no) {
				code, _ := os.read_entire_file(file.fullpath)
				log.infof("Disassembling %s", file)
				log.debugf("Read %d bytes.", len(code))
				out, _ := sim(code)
				out_file := strings.join(
					[]string{filepath.join([]string{actual_dir, file.name}), ".asm"},
					"",
				)
				os.write_entire_file(out_file, transmute([]byte)out)
				log.infof("Wrote %d bytes to %s", len(out), out_file)
				delete(out)
				found = true

			}
		}

		if !found {
			log.infof("Cannot find listing %s", listing_no)
		}

	} else {
		fmt.println("Currently does not support more than 1 file")
	}
}
