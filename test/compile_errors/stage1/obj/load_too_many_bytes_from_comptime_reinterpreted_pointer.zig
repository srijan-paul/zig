export fn entry() void {
    const float: f32 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i64, float_ptr);
    const int_val = int_ptr.*;
    _ = int_val;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:28: error: attempt to read 8 bytes from pointer to f32 which is 4 bytes
