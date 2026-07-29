module humanize

import math.big

fn bbyte(val u64) string {
	return big_bytes(big.integer_from_u64(val))
}

fn bibyte(val u64) string {
	return big_ibytes(big.integer_from_u64(val))
}

struct Big_byte_parse_case {
	in  string
	exp u64
}

fn test_big_byte_parsing() ! {
	tests := [
		Big_byte_parse_case{'42', 42},
		Big_byte_parse_case{'42MB', 42000000},
		Big_byte_parse_case{'42MiB', 44040192},
		Big_byte_parse_case{'42mb', 42000000},
		Big_byte_parse_case{'42mib', 44040192},
		Big_byte_parse_case{'42MIB', 44040192},
		Big_byte_parse_case{'42 MB', 42000000},
		Big_byte_parse_case{'42 MiB', 44040192},
		Big_byte_parse_case{'42 mb', 42000000},
		Big_byte_parse_case{'42 mib', 44040192},
		Big_byte_parse_case{'42 MIB', 44040192},
		Big_byte_parse_case{'42.5MB', 42500000},
		Big_byte_parse_case{'42.5MiB', 44564480},
		Big_byte_parse_case{'42.5 MB', 42500000},
		Big_byte_parse_case{'42.5 MiB', 44564480},
		Big_byte_parse_case{'42M', 42000000},
		Big_byte_parse_case{'42Mi', 44040192},
		Big_byte_parse_case{'42m', 42000000},
		Big_byte_parse_case{'42mi', 44040192},
		Big_byte_parse_case{'42MI', 44040192},
		Big_byte_parse_case{'42 M', 42000000},
		Big_byte_parse_case{'42 Mi', 44040192},
		Big_byte_parse_case{'42 m', 42000000},
		Big_byte_parse_case{'42 mi', 44040192},
		Big_byte_parse_case{'42 MI', 44040192},
		Big_byte_parse_case{'42.5M', 42500000},
		Big_byte_parse_case{'42.5Mi', 44564480},
		Big_byte_parse_case{'42.5 M', 42500000},
		Big_byte_parse_case{'42.5 Mi', 44564480},
		Big_byte_parse_case{'1,005.03 MB', 1005030000},
		Big_byte_parse_case{'12.5 EB', u64(12.5 * f64(ebyte))},
		Big_byte_parse_case{'12.5 E', u64(12.5 * f64(ebyte))},
		Big_byte_parse_case{'12.5 EiB', u64(12.5 * f64(eibyte))},
	]
	for p in tests {
		got := parse_big_bytes(p.in)!
		assert got == big.integer_from_u64(p.exp), 'Expected ${p.exp} for ${p.in}, got ${got}'
	}
}

fn test_big_byte_errors() {
	mut err1 := false
	parse_big_bytes('84 JB') or { err1 = true }
	assert err1, 'Expected error, got success for 84 JB'

	mut err2 := false
	parse_big_bytes('') or { err2 = true }
	assert err2, 'Expected error parsing nothing'
}

fn test_big_bytes() {
	validate_list([
		Test_case{'bytes(0)', bbyte(0), '0 B'},
		Test_case{'bytes(1)', bbyte(1), '1 B'},
		Test_case{'bytes(803)', bbyte(803), '803 B'},
		Test_case{'bytes(999)', bbyte(999), '999 B'},
		Test_case{'bytes(1024)', bbyte(1024), '1.0 kB'},
		Test_case{'bytes(1MB - 1)', bbyte(mbyte - byte), '1000 kB'},
		Test_case{'bytes(1MB)', bbyte(1024 * 1024), '1.0 MB'},
		Test_case{'bytes(1GB - 1K)', bbyte(gbyte - kbyte), '1000 MB'},
		Test_case{'bytes(1GB)', bbyte(gbyte), '1.0 GB'},
		Test_case{'bytes(1TB - 1M)', bbyte(tbyte - mbyte), '1000 GB'},
		Test_case{'bytes(1TB)', bbyte(tbyte), '1.0 TB'},
		Test_case{'bytes(1PB - 1T)', bbyte(pbyte - tbyte), '999 TB'},
		Test_case{'bytes(1PB)', bbyte(pbyte), '1.0 PB'},
		Test_case{'bytes(1PB - 1T)', bbyte(ebyte - pbyte), '999 PB'},
		Test_case{'bytes(1EB)', bbyte(ebyte), '1.0 EB'},
		Test_case{'bytes(0)', bibyte(0), '0 B'},
		Test_case{'bytes(1)', bibyte(1), '1 B'},
		Test_case{'bytes(803)', bibyte(803), '803 B'},
		Test_case{'bytes(1023)', bibyte(1023), '1023 B'},
		Test_case{'bytes(1024)', bibyte(1024), '1.0 KiB'},
		Test_case{'bytes(1MB - 1)', bibyte(mibyte - ibyte), '1024 KiB'},
		Test_case{'bytes(1MB)', bibyte(1024 * 1024), '1.0 MiB'},
		Test_case{'bytes(1GB - 1K)', bibyte(gibyte - kibyte), '1024 MiB'},
		Test_case{'bytes(1GB)', bibyte(gibyte), '1.0 GiB'},
		Test_case{'bytes(1TB - 1M)', bibyte(tibyte - mibyte), '1024 GiB'},
		Test_case{'bytes(1TB)', bibyte(tibyte), '1.0 TiB'},
		Test_case{'bytes(1PB - 1T)', bibyte(pibyte - tibyte), '1023 TiB'},
		Test_case{'bytes(1PB)', bibyte(pibyte), '1.0 PiB'},
		Test_case{'bytes(1PB - 1T)', bibyte(eibyte - pibyte), '1023 PiB'},
		Test_case{'bytes(1EiB)', bibyte(eibyte), '1.0 EiB'},
		Test_case{'bytes(5.5GiB)', bibyte(u64(5.5 * f64(gibyte))), '5.5 GiB'},
		Test_case{'bytes(5.5GB)', bbyte(u64(5.5 * f64(gbyte))), '5.5 GB'},
	])
}

fn test_very_big_bytes() {
	b := big.integer_from_string('15347691069326346944512') or {
		assert false, 'parse failed'
		return
	}
	assert big_bytes(b) == '15 ZB', 'Expected 15 ZB, got ${big_bytes(b)}'
	assert big_ibytes(b) == '13 ZiB', 'Expected 13 ZiB, got ${big_ibytes(b)}'

	b2 := big.integer_from_string('15716035654990179271180288') or {
		assert false, 'parse failed'
		return
	}
	assert big_bytes(b2) == '16 YB', 'Expected 16 YB, got ${big_bytes(b2)}'
	assert big_ibytes(b2) == '13 YiB', 'Expected 13 YiB, got ${big_ibytes(b2)}'
}

fn test_very_very_big_bytes() {
	b := big.integer_from_string('16093220510709943573688614912') or {
		assert false, 'parse failed'
		return
	}
	assert big_bytes(b) == '16 RB', 'Expected 16 RB, got ${big_bytes(b)}'
	assert big_ibytes(b) == '13 RiB', 'Expected 13 RiB, got ${big_ibytes(b)}'
}

struct Parse_big_case {
	in  string
	out string
}

fn test_parse_very_big() ! {
	tests := [
		Parse_big_case{'16 ZB', '16000000000000000000000'},
		Parse_big_case{'16 ZiB', '18889465931478580854784'},
		Parse_big_case{'16.5 ZB', '16500000000000000000000'},
		Parse_big_case{'16.5 ZiB', '19479761741837286506496'},
		Parse_big_case{'16 Z', '16000000000000000000000'},
		Parse_big_case{'16 Zi', '18889465931478580854784'},
		Parse_big_case{'16.5 Z', '16500000000000000000000'},
		Parse_big_case{'16.5 Zi', '19479761741837286506496'},
		Parse_big_case{'16 YB', '16000000000000000000000000'},
		Parse_big_case{'16 YiB', '19342813113834066795298816'},
		Parse_big_case{'16.5 YB', '16500000000000000000000000'},
		Parse_big_case{'16.5 YiB', '19947276023641381382651904'},
		Parse_big_case{'16 Y', '16000000000000000000000000'},
		Parse_big_case{'16 Yi', '19342813113834066795298816'},
		Parse_big_case{'16.5 Y', '16500000000000000000000000'},
		Parse_big_case{'16.5 Yi', '19947276023641381382651904'},
	]
	for test in tests {
		x := parse_big_bytes(test.in)!
		assert x.str() == test.out, 'Expected "${test.out}" for "${test.in}", got ${x}'
	}
}
