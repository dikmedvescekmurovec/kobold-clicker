class_name SafeFile
extends RefCounted
## Writing a save without ever leaving a half-written one. Opening a file for writing truncates it, so
## a crash mid-write is a corrupt save; the text goes to `<path>.tmp` instead and is renamed over the
## real file once it is whole. Both saves (`Inventory`, `MapSave`) write and recover through here.

const TMP := ".tmp"


## Whether `text` got to `path`. On failure the old file is untouched.
static func write(path: String, text: String) -> bool:
	var file := FileAccess.open(path + TMP, FileAccess.WRITE)
	if file == null:
		push_warning("SafeFile: cannot write %s (%d)" % [path + TMP, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(path + TMP, path)
	if error != OK:
		push_warning("SafeFile: cannot write %s (%d)" % [path, error])
	return error == OK


## Call before reading `path`. Godot's rename removes the old file first on Windows, so a crash in that
## instant leaves only the finished .tmp: it is the save, and is put back. A .tmp beside a real file
## is a write that never finished, and is left for the next write to replace.
static func recover(path: String) -> void:
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + TMP):
		DirAccess.rename_absolute(path + TMP, path)
