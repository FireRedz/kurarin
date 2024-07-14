module logging

import log

pub const global = KurarinLogger.create()

pub struct KurarinLogger {
	log.ThreadSafeLog
pub mut:
	logs []string
}

pub fn KurarinLogger.create() &KurarinLogger {
	mut k_logger := &KurarinLogger{
		ThreadSafeLog: log.new_thread_safe_log()
	}

	$if debug {
		k_logger.set_level(.debug)
	} $else {
		k_logger.set_level(.info)
	}

	return k_logger
}

interface Any {
	str() string
}

pub fn get_logger() &KurarinLogger {
	return logging.global
}

pub fn fatal(s Any) {
	mut l := get_logger()
	l.fatal(s.str())
	l.logs << '[${@METHOD}]: ${s.str()}'
}

pub fn error(s Any) {
	mut l := get_logger()
	l.error(s.str())
	l.logs << '[${@METHOD}]: ${s.str()}'
}

pub fn warn(s Any) {
	mut l := get_logger()
	l.warn(s.str())
	l.logs << '[${@METHOD}]: ${s.str()}'
}

pub fn info(s Any) {
	mut l := get_logger()
	l.info(s.str())
	l.logs << '[${@METHOD}]: ${s.str()}'
}

pub fn debug(s Any) {
	mut l := get_logger()
	l.debug(s.str())
	l.logs << '[${@METHOD}]: ${s.str()}'
}
