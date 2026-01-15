// Shared SDL2 C imports to ensure type compatibility
pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
