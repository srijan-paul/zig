const Foo = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .alignment = 0,
        .is_generic = false,
        .is_var_args = true,
        .return_type = u0,
        .args = &.{},
    },
});
comptime { _ = Foo; }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:20: error: varargs functions must have C calling convention
