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


## Under a million nothing changes: it is the string that is on screen today.
func _test_whole_numbers() -> bool:
	_check(BigNumber.format(0.0) == "0", "nothing is nothing: %s" % BigNumber.format(0.0))
	_check(BigNumber.format(7.0) == "7", "seven is seven: %s" % BigNumber.format(7.0))
	_check(BigNumber.format(1000.0) == "1000", "a thousand is spelled out: %s" % BigNumber.format(1000.0))
	_check(BigNumber.format(999999.0) == "999999", "and so is the last six-digit purse: %s" % BigNumber.format(999999.0))
	return true


## And over it, three significant digits -- with the whole number decided first, so a purse that
## rounds up over the line goes over it.
func _test_exponent() -> bool:
	_check(BigNumber.format(1e6) == "1.00e6", "a million turns over: %s" % BigNumber.format(1e6))
	_check(BigNumber.format(1234567.0) == "1.23e6", "three digits and no more: %s" % BigNumber.format(1234567.0))
	_check(BigNumber.format(999999.6) == "1.00e6", "what rounds to a million is written as one: %s" % BigNumber.format(999999.6))
	# The mantissa carry: "%.2f" of 9.999 is "10.00", which is two digits in a one-digit slot.
	_check(BigNumber.format(9.999e8) == "1.00e9", "a mantissa never reaches ten: %s" % BigNumber.format(9.999e8))
	return true


## The one that matters: `log(v) / log(10)` is off by one either way in doubles, so every decade up to
## the float ceiling is asked for by hand.
func _test_every_decade() -> bool:
	for n: int in range(6, 301):
		var written := BigNumber.format(pow(10.0, n))
		_check(written == "1.00e%d" % n, "1e%d lands on its own decade: %s" % [n, written])
	return true


## Signs: the minus is always there, the plus only when it is asked for, and never on nothing.
func _test_signs() -> bool:
	_check(BigNumber.format(-42.0) == "-42", "a small debt keeps its minus: %s" % BigNumber.format(-42.0))
	_check(BigNumber.format(-1234567.0) == "-1.23e6", "and so does a large one: %s" % BigNumber.format(-1234567.0))
	_check(BigNumber.format(5.0, true) == "+5", "a gain is marked: %s" % BigNumber.format(5.0, true))
	_check(BigNumber.format(-5.0, true) == "-5", "a loss is not marked twice: %s" % BigNumber.format(-5.0, true))
	_check(BigNumber.format(0.0, true) == "0", "no change wears no sign: %s" % BigNumber.format(0.0, true))
	_check(BigNumber.format(1e6, true) == "+1.00e6", "a large gain is marked: %s" % BigNumber.format(1e6, true))
	_check(BigNumber.format(-1e6, true) == "-1.00e6", "a large loss too: %s" % BigNumber.format(-1e6, true))
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
