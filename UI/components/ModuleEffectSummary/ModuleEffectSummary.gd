extends RichTextLabel


func set_data(summary_text: String, accent: Color) -> void:
	var escaped := summary_text.replace("[", "[lb]").replace("]", "[rb]")
	var number_pattern := RegEx.new()
	number_pattern.compile("([+-]?\\d+(?:\\.\\d+)?(?:%|\\+)?)")
	text = number_pattern.sub(escaped, "[color=#%s][b]$1[/b][/color]" % accent.to_html(false), true)
