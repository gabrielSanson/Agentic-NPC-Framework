class_name NpcfMultipart
extends RefCounted
## multipart/form-data bodies (CRLF line endings) for the transcription and speech requests. Each part starts with
## "--" + boundary; finish() writes the closing line.


static func new_boundary() -> String:
	var crypto: Crypto = Crypto.new()
	return "npcf" + crypto.generate_random_bytes(12).hex_encode()


static func content_type(boundary: String) -> String:
	return "multipart/form-data; boundary=" + boundary


## One text field.
static func field(boundary: String, name: String, value: String) -> PackedByteArray:
	var head: String = "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n" % [boundary, name]
	return _part(head, value.to_utf8_buffer())


## One file field, with its filename and media type.
static func file(boundary: String, name: String, filename: String, mime: String, data: PackedByteArray) -> PackedByteArray:
	var head: String = "--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [
		boundary, name, filename, mime]
	return _part(head, data)


static func finish(boundary: String) -> PackedByteArray:
	return ("--" + boundary + "--\r\n").to_utf8_buffer()


static func _part(head: String, data: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = head.to_utf8_buffer()
	out.append_array(data)
	out.append_array("\r\n".to_utf8_buffer())
	return out
