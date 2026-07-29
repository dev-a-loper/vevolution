module humanize

fn test_ordinals() {
	validate_list([
		Test_case{'0', ordinal(0), '0th'},
		Test_case{'1', ordinal(1), '1st'},
		Test_case{'2', ordinal(2), '2nd'},
		Test_case{'3', ordinal(3), '3rd'},
		Test_case{'4', ordinal(4), '4th'},
		Test_case{'10', ordinal(10), '10th'},
		Test_case{'11', ordinal(11), '11th'},
		Test_case{'12', ordinal(12), '12th'},
		Test_case{'13', ordinal(13), '13th'},
		Test_case{'21', ordinal(21), '21st'},
		Test_case{'32', ordinal(32), '32nd'},
		Test_case{'43', ordinal(43), '43rd'},
		Test_case{'101', ordinal(101), '101st'},
		Test_case{'102', ordinal(102), '102nd'},
		Test_case{'103', ordinal(103), '103rd'},
		Test_case{'211', ordinal(211), '211th'},
		Test_case{'212', ordinal(212), '212th'},
		Test_case{'213', ordinal(213), '213th'},
	])
}
