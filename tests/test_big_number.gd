extends "res://tests/harness.gd"
## Headless checks for the one formatter every growing quantity is written through. Run from the
## project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_big_number.gd

func _run() -> void:
	_check(_test_whole_numbers() == true, "whole number tests ran to the end")
	_check(_test_exponent() == true, "exponent tests ran to the end")
	_check(_test_every_decade() == true, "decade tests ran to the end")
	_check(_test_signs() == true, "sign tests ran to the end")
	_check(_test_not_a_number() == true, "inf/nan tests ran to the end")
	_check(_test_coin_cap() == true, "coin cap tests ran to the end")
	_report("big number")


## Under a hundred thousand the whole number is spelled out.
func _test_whole_numbers() -> bool:
	_check(BigNumber.format(0.0) == "0", "nothing is nothing: %s" % BigNumber.format(0.0))
	_check(BigNumber.format(7.0) == "7", "seven is seven: %s" % BigNumber.format(7.0))
	_check(BigNumber.format(1000.0) == "1000", "a thousand is spelled out: %s" % BigNumber.format(1000.0))
	_check(BigNumber.format(99999.0) == "99999", "and so is the last five-digit purse: %s" % BigNumber.format(99999.0))
	_check(BigNumber.format(100000.0) == "100K", "six digits are K: %s" % BigNumber.format(100000.0))
	_check(BigNumber.format(607047.0) == "607K", "three digits of them: %s" % BigNumber.format(607047.0))
	_check(BigNumber.format(999999.0) == "1.00M", "and the last carries: %s" % BigNumber.format(999999.0))
	return true


## And over it, three significant digits under the short scale's name -- with the whole number decided
## first, so a purse that rounds up over the line goes over it.
func _test_exponent() -> bool:
	_check(BigNumber.format(1e6) == "1.00M", "a million turns over: %s" % BigNumber.format(1e6))
	_check(BigNumber.format(1234567.0) == "1.23M", "three digits and no more: %s" % BigNumber.format(1234567.0))
	_check(BigNumber.format(999999.6) == "1.00M", "what rounds to a million is written as one: %s" % BigNumber.format(999999.6))
	# The mantissa carry: "%.2f" of 9.999 is "10.00", which is two digits in a one-digit slot.
	_check(BigNumber.format(9.999e8) == "1.00B", "a mantissa never reaches a thousand: %s" % BigNumber.format(9.999e8))
	_check(BigNumber.format(12345678.0) == "12.3M", "tens keep three digits: %s" % BigNumber.format(12345678.0))
	_check(BigNumber.format(123456789.0) == "123M", "and hundreds too: %s" % BigNumber.format(123456789.0))
	_check(BigNumber.format(2.86e12) == "2.86T", "a trillion is T: %s" % BigNumber.format(2.86e12))
	_check(BigNumber.format(9.99e35) == "999Dc", "the last name runs to its thousand: %s" % BigNumber.format(9.99e35))
	_check(BigNumber.format(1e36) == "1.00e36", "and past it is e: %s" % BigNumber.format(1e36))
	return true


## The one that matters: `log(v) / log(10)` is off by one either way in doubles, so every decade up to
## the float ceiling is asked for by hand.
func _test_every_decade() -> bool:
	for n: int in range(5, 301):
		var written := BigNumber.format(pow(10.0, n))
		var named := n / 3 - 1
		var expected := ("1" + "0".repeat(n % 3) + ("." + "0".repeat(2 - n % 3) if n % 3 < 2 else "")
				+ BigNumber.SUFFIXES[named]) if named < BigNumber.SUFFIXES.size() else "1.00e%d" % n
		_check(written == expected, "1e%d lands on its own decade: %s" % [n, written])
	return true


## Signs: the minus is always there, the plus only when it is asked for, and never on nothing.
func _test_signs() -> bool:
	_check(BigNumber.format(-42.0) == "-42", "a small debt keeps its minus: %s" % BigNumber.format(-42.0))
	_check(BigNumber.format(-1234567.0) == "-1.23M", "and so does a large one: %s" % BigNumber.format(-1234567.0))
	_check(BigNumber.format(5.0, true) == "+5", "a gain is marked: %s" % BigNumber.format(5.0, true))
	_check(BigNumber.format(-5.0, true) == "-5", "a loss is not marked twice: %s" % BigNumber.format(-5.0, true))
	_check(BigNumber.format(0.0, true) == "0", "no change wears no sign: %s" % BigNumber.format(0.0, true))
	_check(BigNumber.format(1e6, true) == "+1.00M", "a large gain is marked: %s" % BigNumber.format(1e6, true))
	_check(BigNumber.format(-1e6, true) == "-1.00M", "a large loss too: %s" % BigNumber.format(-1e6, true))
	return true


## Nonsense in, words out: a label is never worth a crash.
func _test_not_a_number() -> bool:
	_check(BigNumber.format(NAN) == "nan", "nan says so: %s" % BigNumber.format(NAN))
	_check(BigNumber.format(INF) == "inf", "and so does inf: %s" % BigNumber.format(INF))
	_check(BigNumber.format(-INF) == "-inf", "with its sign: %s" % BigNumber.format(-INF))
	return true


## The coin burst counts decades, and stops counting at `Coins.MOST`.
func _test_coin_cap() -> bool:
	_check(Coins.count_for(9.0) == 1, "nine gold is one coin")
	_check(Coins.count_for(10.0) == 2, "ten is two")
	_check(Coins.count_for(999.0) == 3, "a nine-hundred purse is three")
	_check(Coins.count_for(1000.0) == 4, "a thousand is four, the log's off-by-one")
	_check(Coins.count_for(1e300) == Coins.MOST, "and an absurd one is capped: %d" % Coins.count_for(1e300))
	return true
