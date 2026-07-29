module humanize

struct Byte_parse_case {
	in  string
	exp u64
}

fn test_byte_parsing() ! {
	tests := [
		Byte_parse_case{'42', 42},
		Byte_parse_case{'42MB', 42000000},
		Byte_parse_case{'42MiB', 44040192},
		Byte_parse_case{'42mb', 42000000},
		Byte_parse_case{'42mib', 44040192},
		Byte_parse_case{'42MIB', 44040192},
		Byte_parse_case{'42 MB', 42000000},
		Byte_parse_case{'42 MiB', 44040192},
		Byte_parse_case{'42 mb', 42000000},
		Byte_parse_case{'42 mib', 44040192},
		Byte_parse_case{'42 MIB', 44040192},
		Byte_parse_case{'42.5MB', 42500000},
		Byte_parse_case{'42.5MiB', 44564480},
		Byte_parse_case{'42.5 MB', 42500000},
		Byte_parse_case{'42.5 MiB', 44564480},
		// No need to say B
		Byte_parse_case{'42M', 42000000},
		Byte_parse_case{'42Mi', 44040192},
		Byte_parse_case{'42m', 42000000},
		Byte_parse_case{'42mi', 44040192},
		Byte_parse_case{'42MI', 44040192},
		Byte_parse_case{'42 M', 42000000},
		Byte_parse_case{'42 Mi', 44040192},
		Byte_parse_case{'42 m', 42000000},
		Byte_parse_case{'42 mi', 44040192},
		Byte_parse_case{'42 MI', 44040192},
		Byte_parse_case{'42.5M', 42500000},
		Byte_parse_case{'42.5Mi', 44564480},
		Byte_parse_case{'42.5 M', 42500000},
		Byte_parse_case{'42.5 Mi', 44564480},
		// Bug #42
		Byte_parse_case{'1,005.03 MB', 1005030000},
		// Large testing.
		Byte_parse_case{'12.5 EB', u64(12.5 * f64(ebyte))},
		Byte_parse_case{'12.5 E', u64(12.5 * f64(ebyte))},
		Byte_parse_case{'12.5 EiB', u64(12.5 * f64(eibyte))},
	]
	for p in tests {
		got := parse_bytes(p.in)!
		assert got == p.exp, 'Expected ${p.exp} for ${p.in}, got ${got}'
	}
}

fn test_byte_errors() {
	// "84 JB" -> unhandled suffix
	mut err1 := false
	parse_bytes('84 JB') or { err1 = true }
	assert err1, 'Expected error, got success for 84 JB'

	// "" -> parse error
	mut err2 := false
	parse_bytes('') or { err2 = true }
	assert err2, 'Expected error parsing nothing'

	// "16 EiB" -> too large (overflow of uint64)
	mut err3 := false
	parse_bytes('16 EiB') or { err3 = true }
	assert err3, 'Expected error for 16 EiB (too large)'
}

fn test_bytes() {
	validate_list([
		Test_case{'bytes(0)', bytes(0), '0 B'},
		Test_case{'bytes(1)', bytes(1), '1 B'},
		Test_case{'bytes(803)', bytes(803), '803 B'},
		Test_case{'bytes(999)', bytes(999), '999 B'},
		Test_case{'bytes(1024)', bytes(1024), '1.0 kB'},
		Test_case{'bytes(9999)', bytes(9999), '10 kB'},
		Test_case{'bytes(1MB - 1)', bytes(mbyte - byte), '1000 kB'},
		Test_case{'bytes(1MB)', bytes(1024 * 1024), '1.0 MB'},
		Test_case{'bytes(1GB - 1K)', bytes(gbyte - kbyte), '1000 MB'},
		Test_case{'bytes(1GB)', bytes(gbyte), '1.0 GB'},
		Test_case{'bytes(1TB - 1M)', bytes(tbyte - mbyte), '1000 GB'},
		Test_case{'bytes(10MB)', bytes(9999 * 1000), '10 MB'},
		Test_case{'bytes(1TB)', bytes(tbyte), '1.0 TB'},
		Test_case{'bytes(1PB - 1T)', bytes(pbyte - tbyte), '999 TB'},
		Test_case{'bytes(1PB)', bytes(pbyte), '1.0 PB'},
		Test_case{'bytes(1PB - 1T)', bytes(ebyte - pbyte), '999 PB'},
		Test_case{'bytes(1EB)', bytes(ebyte), '1.0 EB'},
		Test_case{'bytesN(1234, 3)', bytes_n(1234, 3), '1.23 kB'},
		Test_case{'bytes(0)', ibytes(0), '0 B'},
		Test_case{'bytes(1)', ibytes(1), '1 B'},
		Test_case{'bytes(803)', ibytes(803), '803 B'},
		Test_case{'bytes(1023)', ibytes(1023), '1023 B'},
		Test_case{'bytes(1024)', ibytes(1024), '1.0 KiB'},
		Test_case{'bytes(1MB - 1)', ibytes(mibyte - ibyte), '1024 KiB'},
		Test_case{'bytes(1MB)', ibytes(1024 * 1024), '1.0 MiB'},
		Test_case{'bytes(1GB - 1K)', ibytes(gibyte - kibyte), '1024 MiB'},
		Test_case{'bytes(1GB)', ibytes(gibyte), '1.0 GiB'},
		Test_case{'bytes(1TB - 1M)', ibytes(tibyte - mibyte), '1024 GiB'},
		Test_case{'bytes(1TB)', ibytes(tibyte), '1.0 TiB'},
		Test_case{'bytes(1PB - 1T)', ibytes(pibyte - tibyte), '1023 TiB'},
		Test_case{'bytes(1PB)', ibytes(pibyte), '1.0 PiB'},
		Test_case{'bytes(1PB - 1T)', ibytes(eibyte - pibyte), '1023 PiB'},
		Test_case{'bytes(1EiB)', ibytes(eibyte), '1.0 EiB'},
		Test_case{'bytes(5.5GiB)', ibytes(u64(5.5 * f64(gibyte))), '5.5 GiB'},
		Test_case{'bytes(5.5GB)', bytes(u64(5.5 * f64(gbyte))), '5.5 GB'},
		Test_case{'bytes(123456789, 3)', ibytes_n(123456789, 3), '118 MiB'},
		Test_case{'bytes(123456789, 6)', ibytes_n(123456789, 6), '117.738 MiB'},
	])
}
