/// Represents the index of the file this atom was generated from.
/// This is 'null' when the atom was generated by a synthetic linker symbol.
file: FileIndex,
/// symbol index of the symbol representing this atom
sym_index: Symbol.Index,
/// Size of the atom, used to calculate section sizes in the final binary
size: u32 = 0,
/// List of relocations belonging to this atom
relocs: std.ArrayListUnmanaged(types.Relocation) = .empty,
/// Contains the binary data of an atom, which can be non-relocated
code: std.ArrayListUnmanaged(u8) = .empty,
/// For code this is 1, for data this is set to the highest value of all segments
alignment: Wasm.Alignment = .@"1",
/// Offset into the section where the atom lives, this already accounts
/// for alignment.
offset: u32 = 0,
/// The original offset within the object file. This value is subtracted from
/// relocation offsets to determine where in the `data` to rewrite the value
original_offset: u32 = 0,
/// Previous atom in relation to this atom.
/// is null when this atom is the first in its order
prev: Atom.Index = .null,
/// Contains atoms local to a decl, all managed by this `Atom`.
/// When the parent atom is being freed, it will also do so for all local atoms.
locals: std.ArrayListUnmanaged(Atom.Index) = .empty,

/// Represents the index of an Atom where `null` is considered
/// an invalid atom.
pub const Index = enum(u32) {
    null = std.math.maxInt(u32),
    _,
};

/// Frees all resources owned by this `Atom`.
pub fn deinit(atom: *Atom, gpa: std.mem.Allocator) void {
    atom.relocs.deinit(gpa);
    atom.code.deinit(gpa);
    atom.locals.deinit(gpa);
    atom.* = undefined;
}

/// Sets the length of relocations and code to '0',
/// effectively resetting them and allowing them to be re-populated.
pub fn clear(atom: *Atom) void {
    atom.relocs.clearRetainingCapacity();
    atom.code.clearRetainingCapacity();
}

pub fn format(atom: Atom, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try writer.print("Atom{{ .sym_index = {d}, .alignment = {d}, .size = {d}, .offset = 0x{x:0>8} }}", .{
        @intFromEnum(atom.sym_index),
        atom.alignment,
        atom.size,
        atom.offset,
    });
}

/// Returns the location of the symbol that represents this `Atom`
pub fn symbolLoc(atom: Atom) Wasm.SymbolLoc {
    return .{ .file = atom.file, .index = atom.sym_index };
}

/// Resolves the relocations within the atom, writing the new value
/// at the calculated offset.
pub fn resolveRelocs(atom: *Atom, wasm_bin: *const Wasm) void {
    if (atom.relocs.items.len == 0) return;
    const symbol_name = atom.symbolLoc().getName(wasm_bin);
    log.debug("Resolving relocs in atom '{s}' count({d})", .{
        symbol_name,
        atom.relocs.items.len,
    });

    for (atom.relocs.items) |reloc| {
        const value = atom.relocationValue(reloc, wasm_bin);
        log.debug("Relocating '{s}' referenced in '{s}' offset=0x{x:0>8} value={d}", .{
            (Wasm.SymbolLoc{ .file = atom.file, .index = @enumFromInt(reloc.index) }).getName(wasm_bin),
            symbol_name,
            reloc.offset,
            value,
        });

        switch (reloc.relocation_type) {
            .R_WASM_TABLE_INDEX_I32,
            .R_WASM_FUNCTION_OFFSET_I32,
            .R_WASM_GLOBAL_INDEX_I32,
            .R_WASM_MEMORY_ADDR_I32,
            .R_WASM_SECTION_OFFSET_I32,
            => std.mem.writeInt(u32, atom.code.items[reloc.offset - atom.original_offset ..][0..4], @as(u32, @truncate(value)), .little),
            .R_WASM_TABLE_INDEX_I64,
            .R_WASM_MEMORY_ADDR_I64,
            => std.mem.writeInt(u64, atom.code.items[reloc.offset - atom.original_offset ..][0..8], value, .little),
            .R_WASM_GLOBAL_INDEX_LEB,
            .R_WASM_EVENT_INDEX_LEB,
            .R_WASM_FUNCTION_INDEX_LEB,
            .R_WASM_MEMORY_ADDR_LEB,
            .R_WASM_MEMORY_ADDR_SLEB,
            .R_WASM_TABLE_INDEX_SLEB,
            .R_WASM_TABLE_NUMBER_LEB,
            .R_WASM_TYPE_INDEX_LEB,
            .R_WASM_MEMORY_ADDR_TLS_SLEB,
            => leb.writeUnsignedFixed(5, atom.code.items[reloc.offset - atom.original_offset ..][0..5], @as(u32, @truncate(value))),
            .R_WASM_MEMORY_ADDR_LEB64,
            .R_WASM_MEMORY_ADDR_SLEB64,
            .R_WASM_TABLE_INDEX_SLEB64,
            .R_WASM_MEMORY_ADDR_TLS_SLEB64,
            => leb.writeUnsignedFixed(10, atom.code.items[reloc.offset - atom.original_offset ..][0..10], value),
        }
    }
}

/// From a given `relocation` will return the new value to be written.
/// All values will be represented as a `u64` as all values can fit within it.
/// The final value must be casted to the correct size.
fn relocationValue(atom: Atom, relocation: types.Relocation, wasm_bin: *const Wasm) u64 {
    const target_loc = (Wasm.SymbolLoc{ .file = atom.file, .index = @enumFromInt(relocation.index) }).finalLoc(wasm_bin);
    const symbol = target_loc.getSymbol(wasm_bin);
    if (relocation.relocation_type != .R_WASM_TYPE_INDEX_LEB and
        symbol.tag != .section and
        symbol.isDead())
    {
        const val = atom.thombstone(wasm_bin) orelse relocation.addend;
        return @bitCast(val);
    }
    switch (relocation.relocation_type) {
        .R_WASM_FUNCTION_INDEX_LEB => return symbol.index,
        .R_WASM_TABLE_NUMBER_LEB => return symbol.index,
        .R_WASM_TABLE_INDEX_I32,
        .R_WASM_TABLE_INDEX_I64,
        .R_WASM_TABLE_INDEX_SLEB,
        .R_WASM_TABLE_INDEX_SLEB64,
        => return wasm_bin.function_table.get(.{ .file = atom.file, .index = @enumFromInt(relocation.index) }) orelse 0,
        .R_WASM_TYPE_INDEX_LEB => {
            const obj_file = wasm_bin.file(atom.file) orelse return relocation.index;
            const original_type = obj_file.funcTypes()[relocation.index];
            return wasm_bin.getTypeIndex(original_type).?;
        },
        .R_WASM_GLOBAL_INDEX_I32,
        .R_WASM_GLOBAL_INDEX_LEB,
        => return symbol.index,
        .R_WASM_MEMORY_ADDR_I32,
        .R_WASM_MEMORY_ADDR_I64,
        .R_WASM_MEMORY_ADDR_LEB,
        .R_WASM_MEMORY_ADDR_LEB64,
        .R_WASM_MEMORY_ADDR_SLEB,
        .R_WASM_MEMORY_ADDR_SLEB64,
        => {
            std.debug.assert(symbol.tag == .data);
            if (symbol.isUndefined()) {
                return 0;
            }
            const va: i33 = @intCast(symbol.virtual_address);
            return @intCast(va + relocation.addend);
        },
        .R_WASM_EVENT_INDEX_LEB => return symbol.index,
        .R_WASM_SECTION_OFFSET_I32 => {
            const target_atom_index = wasm_bin.symbol_atom.get(target_loc).?;
            const target_atom = wasm_bin.getAtom(target_atom_index);
            const rel_value: i33 = @intCast(target_atom.offset);
            return @intCast(rel_value + relocation.addend);
        },
        .R_WASM_FUNCTION_OFFSET_I32 => {
            if (symbol.isUndefined()) {
                const val = atom.thombstone(wasm_bin) orelse relocation.addend;
                return @bitCast(val);
            }
            const target_atom_index = wasm_bin.symbol_atom.get(target_loc).?;
            const target_atom = wasm_bin.getAtom(target_atom_index);
            const rel_value: i33 = @intCast(target_atom.offset);
            return @intCast(rel_value + relocation.addend);
        },
        .R_WASM_MEMORY_ADDR_TLS_SLEB,
        .R_WASM_MEMORY_ADDR_TLS_SLEB64,
        => {
            const va: i33 = @intCast(symbol.virtual_address);
            return @intCast(va + relocation.addend);
        },
    }
}

// For a given `Atom` returns whether it has a thombstone value or not.
/// This defines whether we want a specific value when a section is dead.
fn thombstone(atom: Atom, wasm: *const Wasm) ?i64 {
    const atom_name = atom.symbolLoc().getName(wasm);
    if (std.mem.eql(u8, atom_name, ".debug_ranges") or std.mem.eql(u8, atom_name, ".debug_loc")) {
        return -2;
    } else if (std.mem.startsWith(u8, atom_name, ".debug_")) {
        return -1;
    }
    return null;
}

const leb = std.leb;
const log = std.log.scoped(.link);
const mem = std.mem;
const std = @import("std");
const types = @import("types.zig");

const Allocator = mem.Allocator;
const Atom = @This();
const FileIndex = @import("file.zig").File.Index;
const Symbol = @import("Symbol.zig");
const Wasm = @import("../Wasm.zig");
