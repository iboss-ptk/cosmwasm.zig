pub extern fn debug(str_ptr: u32) void;

pub extern fn db_read(key: u32) u32;
pub extern fn db_write(key: u32, value: u32) void;
pub extern fn db_remove(key: u32) void;
