extends RefCounted
class_name RuntimeDiagnostics

const VERBOSE_RUNTIME_LOGS_ARG := "--verbose-runtime-logs"

static func verbose_logs_enabled() -> bool:
	return OS.is_debug_build() and OS.get_cmdline_user_args().has(VERBOSE_RUNTIME_LOGS_ARG)
